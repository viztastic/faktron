# The identities the enquiry function sends as and to (ADR-0001).
#
# The account's SES is in the sandbox, which only sends to verified addresses. That is enough here:
# the function sends from an address on the domain (verified by the DKIM records in main.tf) to one
# inbox (verified by the link SES emails it). No production access is asked for, and none is
# needed unless the site ever emails anybody else.

resource "aws_sesv2_email_identity" "domain" {
  email_identity = local.domain

  dkim_signing_attributes {
    next_signing_key_length = "RSA_2048_BIT"
  }
}

# The inbox. SES sends it a verification email the moment this is applied; someone with the inbox
# clicks the link, and from then on the function can deliver there.
resource "aws_sesv2_email_identity" "inbox" {
  email_identity = local.enquiry_to
}
