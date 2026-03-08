#!/usr/bin/env python
"""
Paperless-ngx pre-consume script.

Environment variables provided by paperless:
  DOCUMENT_SOURCE_PATH   - path to the original document file
  DOCUMENT_WORKING_PATH  - path to the working copy (modify this one)
"""

import os

import pikepdf


def unlock_pdf(file_path):
    print("Unlocking file: " + file_path)
    password = None
    print("reading passwords")
    with open("/run/secrets/paperless/pdf_passwords") as f:
        passwords = f.readlines()
    for p in passwords:
        password = p.strip()
        try:
            with pikepdf.open(
                file_path, password=password, allow_overwriting_input=True
            ) as pdf:
                print("password is working: " + password)
                pdf.save(file_path)
        except pikepdf.PasswordError:
            print("password is not working: " + password)
            continue
    if password is None:
        print("empty password file")


if __name__ == "__main__":
    unlock_pdf(os.environ.get("DOCUMENT_WORKING_PATH"))
