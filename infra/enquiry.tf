# The enquiry function (ADR-0001): enquiry/handler.mjs on Lambda, behind a function URL the page
# posts to. It may send email as the domain to the inbox, and write its own logs; nothing else.

data "archive_file" "enquiry" {
  type        = "zip"
  source_file = "${path.module}/../enquiry/handler.mjs"
  output_path = "${path.module}/enquiry.zip"
}

data "aws_iam_policy_document" "enquiry_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "enquiry" {
  name               = "faktron-enquiry"
  assume_role_policy = data.aws_iam_policy_document.enquiry_assume.json
}

resource "aws_iam_role_policy_attachment" "enquiry_logs" {
  role       = aws_iam_role.enquiry.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "aws_iam_policy_document" "enquiry" {
  statement {
    sid       = "SendAsTheDomainToTheInbox"
    effect    = "Allow"
    actions   = ["ses:SendEmail"]
    resources = [aws_sesv2_email_identity.domain.arn, aws_sesv2_email_identity.inbox.arn]

    condition {
      test     = "StringEquals"
      variable = "ses:FromAddress"
      values   = [local.enquiry_from]
    }
  }
}

resource "aws_iam_role_policy" "enquiry" {
  name   = "faktron-enquiry-inline"
  role   = aws_iam_role.enquiry.id
  policy = data.aws_iam_policy_document.enquiry.json
}

resource "aws_cloudwatch_log_group" "enquiry" {
  name              = "/aws/lambda/faktron-enquiry"
  retention_in_days = 30
}

resource "aws_lambda_function" "enquiry" {
  function_name    = "faktron-enquiry"
  description      = "The enquiry form on faktron.com/contact: checks the fields and emails the inbox"
  role             = aws_iam_role.enquiry.arn
  runtime          = "nodejs22.x"
  architectures    = ["arm64"]
  handler          = "handler.handler"
  filename         = data.archive_file.enquiry.output_path
  source_code_hash = data.archive_file.enquiry.output_base64sha256
  memory_size      = 128
  timeout          = 10

  # No reserved concurrency: the account's Lambda ceiling is at the minimum AWS grants a new
  # account, and reserving any of it is refused. The honeypot and the ten-second timeout are what
  # bound a flood of posts; SES's sandbox caps the sending at 200 a day regardless.

  environment {
    variables = {
      ENQUIRY_TO   = local.enquiry_to
      ENQUIRY_FROM = local.enquiry_from
    }
  }

  depends_on = [aws_cloudwatch_log_group.enquiry, aws_iam_role_policy_attachment.enquiry_logs]
}

# The URL the page posts to. Open to the internet, as a form must be; the browser is told only
# https://faktron.com may call it, and the function itself refuses anything but a well-formed POST.
resource "aws_lambda_function_url" "enquiry" {
  function_name      = aws_lambda_function.enquiry.function_name
  authorization_type = "NONE"

  cors {
    allow_origins = ["https://${local.domain}"]
    allow_methods = ["POST"]
    allow_headers = ["content-type"]
    max_age       = 86400
  }
}

resource "aws_lambda_permission" "enquiry_url" {
  statement_id           = "AllowTheFunctionUrl"
  action                 = "lambda:InvokeFunctionUrl"
  function_name          = aws_lambda_function.enquiry.function_name
  principal              = "*"
  function_url_auth_type = "NONE"
}
