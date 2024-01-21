# pics-ios

A picture gallery for iOS.

1. Take a photo
1. View it in the gallery
1. Share a link

Not released to the App Store.

## Releases

To release a new version to TestFlight, push to the master branch.

### Setup

1. In Xcode, create a new Apple Distribution signing certificate.
1. In Keychain Access, export the certificate in P12 format. Provide a certificate password when requested.
1. Base 64 encode the certificate: ```base64 -i cert.p12 -o cert.p12.b64```
1. Add the base 64 encoded certificate along with its password to GitHub Actions secrets.
1. Push to the master branch! Fastlane generates provisioning profiles as needed.
