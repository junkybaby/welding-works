<?php

// Load local .env if present (for XAMPP/local dev).
if (!function_exists("load_local_env")) {
  function load_local_env() {
    static $loaded = false;
    if ($loaded) return;
    $loaded = true;

    $envPath = __DIR__ . "/.env";
    if (!file_exists($envPath)) return;

    $lines = file($envPath, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
    if (!is_array($lines)) return;

    foreach ($lines as $line) {
      $line = trim($line);
      if ($line === "" || str_starts_with($line, "#")) continue;
      $parts = explode("=", $line, 2);
      if (count($parts) !== 2) continue;
      $key = trim($parts[0]);
      $value = trim($parts[1]);
      if ($key === "" || getenv($key) !== false) continue;
      putenv("{$key}={$value}");
      $_ENV[$key] = $value;
    }
  }
}
load_local_env();

function load_mail_config() {
  $config = [];
  $configPath = __DIR__ . "/mail_config.php";
  if (file_exists($configPath)) {
    $cfg = require $configPath;
    if (is_array($cfg)) {
      $config = $cfg;
    }
  }
  $envOverrides = [
    "SMTP_HOST" => getenv("SMTP_HOST") ?: null,
    "SMTP_PORT" => getenv("SMTP_PORT") ?: null,
    "SMTP_SECURE" => getenv("SMTP_SECURE") ?: null,
    "SMTP_USER" => getenv("SMTP_USER") ?: null,
    "SMTP_PASS" => getenv("SMTP_PASS") ?: null,
    "SMTP_FROM" => getenv("SMTP_FROM") ?: null,
    "SMTP_FROM_NAME" => getenv("SMTP_FROM_NAME") ?: null,
    "SMTP_TIMEOUT" => getenv("SMTP_TIMEOUT") ?: null,
    "TESDA_CC_EMAIL" => getenv("TESDA_CC_EMAIL") ?: null,
  ];
  foreach ($envOverrides as $key => $value) {
    if ($value !== null && $value !== "") {
      $config[$key] = $value;
    }
  }
  return $config;
}

function send_mail($toEmail, $subject, $bodyText, $options = []) {
  $GLOBALS["MAIL_LAST_ERROR"] = null;
  $cfg = load_mail_config();
  $smtpUser = $cfg["SMTP_USER"] ?? "";
  $smtpPass = $cfg["SMTP_PASS"] ?? "";
  $from = $cfg["SMTP_FROM"] ?? ($smtpUser !== "" ? $smtpUser : "no-reply@localhost");
  $fromName = $cfg["SMTP_FROM_NAME"] ?? "Welding Works";
  $ccList = [];
  if (!empty($options["cc"])) {
    $rawCc = is_array($options["cc"]) ? $options["cc"] : [$options["cc"]];
    foreach ($rawCc as $ccEmail) {
      $ccEmail = trim((string)$ccEmail);
      if ($ccEmail !== "") {
        $ccList[] = $ccEmail;
      }
    }
  }

  $autoload = __DIR__ . "/vendor/autoload.php";
  $legacyAutoload = __DIR__ . "/PHPMailer/src/PHPMailer.php";

  if (file_exists($autoload) || file_exists($legacyAutoload)) {
    if (file_exists($autoload)) {
      require_once $autoload;
    } else {
      require_once __DIR__ . "/PHPMailer/src/PHPMailer.php";
      require_once __DIR__ . "/PHPMailer/src/SMTP.php";
      require_once __DIR__ . "/PHPMailer/src/Exception.php";
    }

    try {
      if ($smtpUser === "" || $smtpPass === "") {
        $GLOBALS["MAIL_LAST_ERROR"] = "Missing SMTP_USER or SMTP_PASS in mail_config.php.";
        return false;
      }
      $mail = new \PHPMailer\PHPMailer\PHPMailer(true);
      $mail->isSMTP();
      $mail->Host = $cfg["SMTP_HOST"] ?? "smtp.gmail.com";
      $mail->SMTPAuth = true;
      $mail->Username = $smtpUser;
      $mail->Password = $smtpPass;
      $mail->Port = intval($cfg["SMTP_PORT"] ?? 587);
      $mail->Timeout = intval($cfg["SMTP_TIMEOUT"] ?? 12);
      $secure = $cfg["SMTP_SECURE"] ?? "tls";
      if ($secure !== "") {
        $mail->SMTPSecure = $secure;
      }
      if ($smtpUser !== "" && $from !== $smtpUser) {
        $from = $smtpUser;
      }
      $mail->setFrom($from, $fromName);
      $mail->addAddress($toEmail);
      foreach ($ccList as $ccEmail) {
        $mail->addCC($ccEmail);
      }
      $mail->Subject = $subject;
      $mail->Body = $bodyText;
      $mail->AltBody = $bodyText;
      return $mail->send();
    } catch (Throwable $e) {
      $GLOBALS["MAIL_LAST_ERROR"] = $e->getMessage();
    }
  }

  // Native SMTP fallback for deployments without PHPMailer or mail().
  try {
    if ($smtpUser === "" || $smtpPass === "") {
      $GLOBALS["MAIL_LAST_ERROR"] = "Missing SMTP_USER or SMTP_PASS in mail_config.php.";
      return false;
    }

    $host = $cfg["SMTP_HOST"] ?? "smtp.gmail.com";
    $port = intval($cfg["SMTP_PORT"] ?? 587);
    $secure = strtolower(trim((string)($cfg["SMTP_SECURE"] ?? "tls")));
    $timeout = intval($cfg["SMTP_TIMEOUT"] ?? 12);

    $remote = ($secure === "ssl" ? "ssl://" : "") . $host . ":" . $port;
    $stream = @stream_socket_client($remote, $errno, $errstr, $timeout, STREAM_CLIENT_CONNECT);
    if (!$stream) {
      $GLOBALS["MAIL_LAST_ERROR"] = "SMTP connect failed ({$errno}): {$errstr}";
      return false;
    }

    @stream_set_timeout($stream, $timeout);

    $smtpRead = function () use ($stream) {
      $lines = [];
      while (!feof($stream)) {
        $line = @fgets($stream, 515);
        if ($line === false) break;
        $lines[] = rtrim($line, "\r\n");
        if (strlen($line) >= 4 && ctype_digit(substr($line, 0, 3)) && $line[3] === " ") {
          break;
        }
      }
      return $lines;
    };

    $smtpWrite = function (string $command) use ($stream) {
      @fwrite($stream, $command . "\r\n");
    };

    $expect = function (array $codes, string $context) use ($smtpRead) {
      $lines = $smtpRead();
      $first = $lines[0] ?? "";
      $code = intval(substr($first, 0, 3));
      if (!in_array($code, $codes, true)) {
        throw new RuntimeException($context . ": " . implode(" | ", $lines));
      }
      return $lines;
    };

    $expect([220], "SMTP banner");
    $smtpWrite("EHLO localhost");
    $expect([250], "EHLO");

    if ($secure === "tls") {
      $smtpWrite("STARTTLS");
      $expect([220], "STARTTLS");
      if (@stream_socket_enable_crypto($stream, true, STREAM_CRYPTO_METHOD_TLS_CLIENT) !== true) {
        throw new RuntimeException("Failed to enable TLS.");
      }
      $smtpWrite("EHLO localhost");
      $expect([250], "EHLO after STARTTLS");
    }

    $smtpWrite("AUTH LOGIN");
    $expect([334], "AUTH LOGIN");
    $smtpWrite(base64_encode($smtpUser));
    $expect([334], "SMTP username");
    $smtpWrite(base64_encode($smtpPass));
    $expect([235], "SMTP password");

    $recipientList = array_merge([$toEmail], $ccList);
    $messageHeaders = [
      "From: {$fromName} <{$from}>",
      "To: {$toEmail}",
      "Subject: {$subject}",
      "MIME-Version: 1.0",
      "Content-Type: text/plain; charset=UTF-8",
      "Content-Transfer-Encoding: 8bit",
    ];
    if (!empty($ccList)) {
      $messageHeaders[] = "Cc: " . implode(", ", $ccList);
    }
    $message = implode("\r\n", $messageHeaders) . "\r\n\r\n" . $bodyText;
    $message = preg_replace("/^\./m", "..", $message);

    $smtpWrite("MAIL FROM:<{$from}>");
    $expect([250], "MAIL FROM");
    foreach ($recipientList as $recipient) {
      $smtpWrite("RCPT TO:<{$recipient}>");
      $expect([250, 251], "RCPT TO");
    }
    $smtpWrite("DATA");
    $expect([354], "DATA");
    $smtpWrite($message . "\r\n.");
    $expect([250], "message body");
    $smtpWrite("QUIT");
    fclose($stream);
    return true;
  }
  catch (Throwable $e) {
    $GLOBALS["MAIL_LAST_ERROR"] = $e->getMessage();
    if (isset($stream) && is_resource($stream)) {
      fclose($stream);
    }
    if (getenv("DEV_SHOW_OTP") === "1") {
      return true;
    }
    return false;
  }
}

function send_output_mail($toEmail, $subject, $bodyText) {
  $cfg = load_mail_config();
  $tesdaCc = trim((string)($cfg["TESDA_CC_EMAIL"] ?? ""));
  $options = [];
  if ($tesdaCc !== "") {
    $options["cc"] = [$tesdaCc];
  }
  return send_mail($toEmail, $subject, $bodyText, $options);
}
