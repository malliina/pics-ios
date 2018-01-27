#!/usr/bin/env bash

# Injects Amazon Cognito credentials to a plist file
if [ "$APPCENTER_BRANCH" == "master" ];
then
	cp $APPCENTER_SOURCE_DIRECTORY/pics-ios/Credentials-template.plist $APPCENTER_SOURCE_DIRECTORY/pics-ios/Credentials.plist
    plutil -replace CognitoClientId -string "\$(COGNITO_ID)" $APPCENTER_SOURCE_DIRECTORY/pics-ios/Credentials.plist
    plutil -replace CognitoClientSecret -string "\$(COGNITO_SECRET)" $APPCENTER_SOURCE_DIRECTORY/pics-ios/Credentials.plist
    plutil -replace CognitoUserPoolId -string "\$(COGNITO_POOL)" $APPCENTER_SOURCE_DIRECTORY/pics-ios/Credentials.plist
fi
