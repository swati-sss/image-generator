#!/usr/bin/env bash

function check_xcode_version() {
    if [ "${JENKINS_USER}" ] ; then
        return 0;
    fi
    local RECOMMENDED_VERSION="Xcode 12.3"
    local XCODE_VERSION=$(xcodebuild -version | head -n 1 | xargs)

    if [[ "${XCODE_VERSION}" =~ ^${RECOMMENDED_VERSION}(\.[[:digit:]])?$ ]] ; then
        echo "Xcode Version : ${XCODE_VERSION}"
        exit 0;
    else
        echo "**** Error: Looks like you might be on the wrong version of Xcode ****";
        echo "You should be using ${RECOMMENDED_VERSION}";
        echo "Your Current version - $(xcodebuild -version)";
        echo "Execute \`sudo xcode-select -s /path/to/${RECOMMENDED_VERSION}/\` to switch";
        exit 1;
    fi
}

function check_encrypted_key() {
    local placeholder=$1
    local value=${!2}

    if [[ "$value" == *"ERROR"* ]]; then
      echo "The encrypted token '$placeholder' was not decrypted successfully"
      return 1
    fi

    if [ -z "$value" ]; then
      echo "The encrypted token '$placeholder' is blank."
      return 1
    fi

    sed -i '' "s/$placeholder/$value/g" $WORKSPACE/Configuration/SecureKeys-Release.xcconfig;
}

function check_encrypted_keys() {
  if [ "${JENKINS_USER}" ]; then
    echo "Checking if encrypted keys are set correctly"
    if [[ "${BRAZE_KEY}|${PERIMETERX_KEY}|${QUANTUMMETRIC_UID}|${FLIPP_KEY}|${BAZAARVOICE_LICENCE_KEY}" == *"ERROR"* ]]; then
      echo "One of the Encrypted Tokens is Invalid. Please regenerate the token and set correctly in the looper YML"
      exit 1
    fi

    if [[ -z ${BRAZE_KEY} || -z ${PERIMETERX_KEY} || -z ${QUANTUMMETRIC_UID} || -z ${FLIPP_KEY} || -z ${BAZAARVOICE_LICENCE_KEY} ]]; then
      echo "One of the Encrypted Tokens is Blank. Please regenerate the token and set correctly in the looper YML"
      exit 1
    fi

    if [[ "${GOOGLEMAPS_API_KEY}" == *"ERROR"* ]]; then
      echo "Google API Key Encrypted Tokens is Invalid. Please regenerate the token and set correctly in the looper YML"
      exit 1
    fi
    

    # Check whether BOD US Privacy Rights are enabled for a given Market (from market.properties)
    if [[ -z "$BOD_US_PRIVACY_KEY_ENABLED" ]]; then
        echo "BOD_US_PRIVACY_KEY not required for this market"
    else
        if [[ "${BOD_US_PRIVACY_KEY}" == *"ERROR"* ]]; then
            echo "US Privacy Key Encrypted Token is Invalid. Please regenerate the token and set correctly in the looper YML"
            exit 1
        fi

        sed -i '' 's/USPRIVACYKEY_PROD/'"${BOD_US_PRIVACY_KEY}"'/g' $WORKSPACE/Configuration/SecureKeys-Release.xcconfig;
    fi
    # Check whether PENDO_KEY are enabled for a given Market (from market.properties)
    if [[ -z "$PENDO_KEY" ]]; then
        echo "PENDO_KEY not required for this market"
    else
        if [[ "${PENDO_KEY}" == *"ERROR"* ]]; then
            echo "PENDO_KEY Encrypted Token is Invalid. Please regenerate the token and set correctly in the looper YML"
            exit 1
        fi

        sed -i '' 's/PENDO_PROD/'"${PENDO_KEY}"'/g' $WORKSPACE/Configuration/SecureKeys-Release.xcconfig;
    fi

    # Check whether APPSFLYER_DEV_KEY are enabled for a given Market (from market.properties)
    if [[ -z "$APPSFLYER_DEV_KEY" ]]; then
        echo "APPSFLYER_DEV_KEY not required for this market"
    else
        if [[ "${APPSFLYER_DEV_KEY}" == *"ERROR"* ]]; then
            echo "APPSFLYER_DEV_KEY Encrypted Token is Invalid. Please regenerate the token and set correctly in the looper YML"
            exit 1
        fi

        sed -i '' 's/APPSFLYER_DEV_KEY_PROD/'"${APPSFLYER_DEV_KEY}"'/g' $WORKSPACE/Configuration/SecureKeys-Release.xcconfig;
    fi

    # Check whether APPSFLYER_APP_ID are enabled for a given Market (from market.properties)
    if [[ -z "$APPSFLYER_APP_ID" ]]; then
        echo "APPSFLYER_APP_ID not required for this market"
    else
        if [[ "${APPSFLYER_APP_ID}" == *"ERROR"* ]]; then
            echo "APPSFLYER_APP_ID Encrypted Token is Invalid. Please regenerate the token and set correctly in the looper YML"
            exit 1
        fi

        sed -i '' 's/APPSFLYER_APP_ID_PROD/'"${APPSFLYER_APP_ID}"'/g' $WORKSPACE/Configuration/SecureKeys-Release.xcconfig;
    fi

    sed -i '' 's/GOOGLEMAPS_PROD/'"${GOOGLEMAPS_API_KEY}"'/g' $WORKSPACE/Configuration/SecureKeys-Release.xcconfig;
    sed -i '' 's/BRAZE_PROD/'"${BRAZE_KEY}"'/g' $WORKSPACE/Configuration/SecureKeys-Release.xcconfig;
    sed -i '' 's/PERIMETERX_PROD/'"${PERIMETERX_KEY}"'/g' $WORKSPACE/Configuration/SecureKeys-Release.xcconfig;
    sed -i '' 's/QUANTUMMETRIC_PROD/'"${QUANTUMMETRIC_UID}"'/g' $WORKSPACE/Configuration/SecureKeys-Release.xcconfig;
    sed -i '' 's/BAZAARVOICE_PROD/'"${BAZAARVOICE_LICENCE_KEY}"'/g' $WORKSPACE/Configuration/SecureKeys-Release.xcconfig;

    if [ -w $WORKSPACE/Configuration/SecureKeys-Base.xcconfig ]; then
      sed -i '' 's/BAZAARVOICE_SECRET_INJECT/'"${BAZAARVOICE_LICENCE_KEY}"'/g' \
        $WORKSPACE/Configuration/SecureKeys-Base.xcconfig;
    fi

    # Check whether or not Airship is enabled for a given Market (from market.properties)
    if [[ -z "$AIRSHIP_ENABLED" ]]; then
	   echo "Airship not required for this market"
    else
        if [ "$AIRSHIP_ENABLED" == true ]; then
            if [[ "${AIRSHIP_API_KEY}|${AIRSHIP_API_SECRET}" == *"ERROR"* ]]; then
              echo "Airship Tokens is Invalid. Please regenerate the token and set correctly in the looper YML"
              exit 1
            fi

            if [[ -z ${AIRSHIP_API_KEY} || -z ${AIRSHIP_API_SECRET} ]]; then
              echo "Airship token is Blank. Please regenerate the token and set correctly in the looper YML"
              exit 1
            fi

            sed -i '' 's/AIRSHIP_KEY_PROD/'"${AIRSHIP_API_KEY}"'/g' $WORKSPACE/Configuration/SecureKeys-Release.xcconfig;
            sed -i '' 's/AIRSHIP_SECRET_PROD/'"${AIRSHIP_API_SECRET}"'/g' $WORKSPACE/Configuration/SecureKeys-Release.xcconfig;
        fi
	fi

    # FISPayPageID Key
    sed -i '' 's/FIS_PAYPAGEID_TEFLON/'"${FIS_PAYPAGEID_KEY}"'/g' $WORKSPACE/Configuration/SecureKeys-Release.xcconfig;
    sed -i '' 's/FIS_PAYPAGEID_PROD_DUMMY/'"${FIS_PAYPAGEID_PROD_KEY}"'/g' $WORKSPACE/Configuration/SecureKeys-Release.xcconfig;

    # Dynamic Size Guide
    local dynamic_size_guide_keys=(
        DSG_NATIVE_PARTNER_KEY_PROD:DSG_NATIVE_PARTNER_KEY
        DSG_NATIVE_PARTNER_SERVICE_KEY_PROD:DSG_NATIVE_PARTNER_SERVICE_KEY
    )
    for replacement in ${dynamic_size_guide_keys[@]}; do
        local key=${replacement%:*}
        local value=${replacement##*:}
        echo "Replacing: $key with value of $value"
        check_encrypted_key $key $value || exit 1
    done

    # Fit Predictor
    local fit_predictor_keys=(
        FIT_PREDICTOR_PARTNER_KEY_PROD:FIT_PREDICTOR_PARTNER_KEY
        FIT_PREDICTOR_SERVICE_KEY_PROD:FIT_PREDICTOR_SERVICE_KEY
        FIT_PREDICTOR_EMAIL_SALT_PROD:FIT_PREDICTOR_EMAIL_SALT
    )
    for replacement in ${fit_predictor_keys[@]}; do
        local key=${replacement%:*}
        local value=${replacement##*:}
        echo "Replacing: $key with value of $value"
        check_encrypted_key $key $value || exit 1
    done

    # OpticalKeys
    sed -i '' 's:OPTICAL_DEV_KEY:"'${DEV_PRIVATE_KEY}'":g' ${WORKDIR}/markets/vc-assoc/Configuration/SecureKeys-Release.xcconfig;
    sed -i '' 's:OPTICAL_STAG_KEY:"'${STAGING_PRIVATE_KEY}'":g' ${WORKDIR}/markets/vc-assoc/Configuration/SecureKeys-Release.xcconfig;
    sed -i '' 's:OPTICAL_PROD_KEY:"'${PROD_PRIVATE_KEY}'":g' ${WORKDIR}/markets/vc-assoc/Configuration/SecureKeys-Release.xcconfig;
    sed -i '' 's:OPTICAL_PROD_KEY:"'${PROD_PRIVATE_KEY}'":g' ${WORKDIR}/markets/vc-assoc/Configuration/SecureKeys-Debug.xcconfig;
    sed -i '' 's:OPT_ECW_STG_PWD:"'${OPT_ECW_PWD_STG}'":g' ${WORKDIR}/markets/vc-assoc/Configuration/SecureKeys-Debug.xcconfig;
    sed -i '' 's:OPT_ECW_PROD_PWD:"'${OPT_ECW_PWD_PROD}'":g' ${WORKDIR}/markets/vc-assoc/Configuration/SecureKeys-Release.xcconfig;

    sed -i '' 's/FLIPP_PROD/'"${FLIPP_KEY}"'/g' $WORKSPACE/Configuration/SecureKeys-Release.xcconfig;
    # AppsFlyer's Dev Key, used both in debug and release modes
    sed -i '' 's/APPSFLYER_DEV_KEY_PROD/'"${APPSFLYER_DEV_KEY}"'/g' $WORKSPACE/Configuration/SecureKeys-Release.xcconfig;
    sed -i '' 's/APPSFLYER_APP_ID_PROD/'"${APPSFLYER_APP_ID}"'/g' $WORKSPACE/Configuration/SecureKeys-Release.xcconfig;
    sed -i '' 's/APPSFLYER_ONELINK_AUTH_PROD/'"${APPSFLYER_ONELINK_AUTH}"'/g' $WORKSPACE/Configuration/SecureKeys-Release.xcconfig;
			
    # ThreatMetrix orgID is provided by CCM. This is a fallback.
    sed -i '' 's/THREATMETRIX_PROD_ORG_ID_PROD/'"${THREATMETRIX_PROD_ORG_ID}"'/g' $WORKSPACE/Configuration/SecureKeys-Release.xcconfig;
    # Encryption key used by different features to encrypt/decrypt strings.
    sed -i '' 's/ENCRYPTION_PRIVATE_KEY_PROD/'"${ENCRYPTION_KEY}"'/g' $WORKSPACE/Configuration/SecureKeys-Release.xcconfig;
    sed -i '' 's/CONSUMER_ID_KEY_PROD/${CONSUMER_ID_KEY}/g' $WORKSPACE/Configuration/SecureKeys-Release.xcconfig;

    local compass_keys=(
        COMPASS_PROD_LOGGED_IN_CONSUMER_ID_PROD:COMPASS_PROD_LOGGED_IN_CONSUMER_ID
        COMPASS_STAGE_LOGGED_IN_CONSUMER_ID_STAGE:COMPASS_STAGE_LOGGED_IN_CONSUMER_ID
        COMPASS_PROD_GUEST_CONSUMER_ID_PROD:COMPASS_PROD_GUEST_CONSUMER_ID
        COMPASS_STAGE_GUEST_CONSUMER_ID_STAGE:COMPASS_STAGE_GUEST_CONSUMER_ID
        COMPASS_PROD_GUEST_CLIENT_SECRET_PROD:COMPASS_PROD_GUEST_CLIENT_SECRET
        COMPASS_STAGE_GUEST_CLIENT_SECRET_STAGE:COMPASS_STAGE_GUEST_CLIENT_SECRET
    )
    for replacement in ${compass_keys[@]}; do
        local key=${replacement%:*}
        local value=${replacement##*:}
        echo "Replacing: $key with value of $value"
        check_encrypted_key $key $value || exit 1
    done

   # Livestream keys
    sed -i '' 's/TSL_SHARED_SECRETE_PROD/'"${TSL_SHARED_SECRETE}"'/g' $WORKSPACE/Configuration/SecureKeys-Release.xcconfig;
    sed -i '' 's/TSL_CLIENT_KEY_PROD/'"${TSL_CLIENT_KEY}"'/g' $WORKSPACE/Configuration/SecureKeys-Release.xcconfig;
    sed -i '' 's/LIVESTREAM_SALT_KEY_PROD/'"${LIVESTREAM_SALT_KEY}"'/g' $WORKSPACE/Configuration/SecureKeys-Release.xcconfig;
    sed -i '' 's/TSL_DEV_SHARED_SECRETE_PROD/'"${TSL_DEV_SHARED_SECRETE}"'/g' $WORKSPACE/Configuration/SecureKeys-Release.xcconfig;
    sed -i '' 's/TSL_DEV_CLIENT_KEY_PROD/'"${TSL_DEV_CLIENT_KEY}"'/g' $WORKSPACE/Configuration/SecureKeys-Release.xcconfig;
    sed -i '' 's/LIVESTREAM_DEV_SALT_KEY_PROD/'"${LIVESTREAM_DEV_SALT_KEY}"'/g' $WORKSPACE/Configuration/SecureKeys-Release.xcconfig;
    
    # AROptical keys
    SAFE_AROPTICAL_KEY=$(printf '%s' "$AROPTICAL_KEY" | sed -e 's/[\/&]/\\&/g' -e 's/\\/\\\\/g')
    SAFE_AROPTICAL_KEY_DEV=$(printf '%s' "$AROPTICAL_DEV_KEY" | sed -e 's/[\/&]/\\&/g' -e 's/\\/\\\\/g')

    sed -i '' "s#AROPTICAL_KEY_PROD#${SAFE_AROPTICAL_KEY}#g" "$WORKSPACE/Configuration/SecureKeys-Release.xcconfig"
    sed -i '' "s#AROPTICAL_KEY_PROD#${SAFE_AROPTICAL_KEY_DEV}#g" "$WORKSPACE/Configuration/SecureKeys-Release.xcconfig"

    # Acoustic keys
    sed -i '' 's/ACOUSTIC_APP_KEY_PROD/'"${ACOUSTIC_SDK_APP_KEY}"'/g' $WORKSPACE/Configuration/SecureKeys-Release.xcconfig;
    sed -i '' 's/ACOUSTIC_CLIENT_SECRET_PROD/'"${ACOUSTIC_SDK_CLIENT_SECRET}"'/g' $WORKSPACE/Configuration/SecureKeys-Release.xcconfig;
    sed -i '' 's/ACOUSTIC_IGNI_TOKEN_PROD/'"${ACOUSTIC_SDK_IGNI_TOKEN}"'/g' $WORKSPACE/Configuration/SecureKeys-Release.xcconfig;
    sed -i '' 's/ACOUSTIC_REFRESH_TOKEN_PROD/'"${ACOUSTIC_SDK_REFRESH_TOKEN}"'/g' $WORKSPACE/Configuration/SecureKeys-Release.xcconfig;

    # SFMC keys
    sed -i '' 's/SFMC_MID_PROD/'"${SFMC_PROD_MID}"'/g' $WORKSPACE/Configuration/SecureKeys-Release.xcconfig;
    sed -i '' 's/SFMC_APPID_PROD/'"${SFMC_PROD_APP_ID}"'/g' $WORKSPACE/Configuration/SecureKeys-Release.xcconfig;
    sed -i '' 's/SFMC_TOKEN_PROD/'"${SFMC_PROD_ACCESS_TOKEN}"'/g' $WORKSPACE/Configuration/SecureKeys-Release.xcconfig;

    # Branch key
    sed -i '' 's/BRANCH_KEY_PROD/'"${BRANCH_API_KEY}"'/g' $WORKSPACE/Configuration/SecureKeys-Release.xcconfig;

    # Button key
    sed -i '' 's/BUTTON_ID_PROD/'"${BUTTON_PROD_ID}"'/g' $WORKSPACE/Configuration/SecureKeys-Release.xcconfig;

    # Synchrony keys
    sed -i '' 's/SYNCHRONY_PROD_CLIENT_ID/'"${SYNCHRONY_CLIENT_ID}"'/g' $WORKSPACE/Configuration/SecureKeys-Release.xcconfig;
    sed -i '' 's/SYNCHRONY_PROD_CLIENT_KEY/'"${SYNCHRONY_CLIENT_KEY}"'/g' $WORKSPACE/Configuration/SecureKeys-Release.xcconfig;
    sed -i '' 's/SYNCHRONY_BUSINESS_PROD_CLIENT_ID/'"${SYNCHRONY_BUSINESS_CLIENT_ID}"'/g' $WORKSPACE/Configuration/SecureKeys-Release.xcconfig;
    sed -i '' 's/SYNCHRONY_BUSINESS_PROD_CLIENT_KEY/'"${SYNCHRONY_BUSINESS_CLIENT_KEY}"'/g' $WORKSPACE/Configuration/SecureKeys-Release.xcconfig;


    # We should also check unencrypted keys
    if [[ -n "${BRAZE_KEY_DEBUG}" ]]; then
        sed -i '' 's/BRAZE_API_KEY=.*/BRAZE_API_KEY="${BRAZE_KEY_DEBUG}"/g' $WORKSPACE/Configuration/SecureKeys-Debug.xcconfig
    fi
    if [[ -n "${PENDO_KEY}" ]]; then
        sed -i '' 's/PENDO_API_KEY=.*/PENDO_API_KEY="${PENDO_KEY}"/g' $WORKSPACE/Configuration/SecureKeys-Debug.xcconfig
    fi
    if [[ -n "${APPSFLYER_DEV_KEY}" ]]; then
        sed -i '' 's/APPSFLYER_KEY=.*/APPSFLYER_KEY="${APPSFLYER_DEV_KEY}"/g' $WORKSPACE/Configuration/SecureKeys-Debug.xcconfig
    fi
    if [[ -n "${APPSFLYER_APP_ID}" ]]; then
        sed -i '' 's/APPSFLYER_ID=.*/APPSFLYER_ID="${APPSFLYER_APP_ID}"/g' $WORKSPACE/Configuration/SecureKeys-Debug.xcconfig
    fi
    if [[ -n "${AIRSHIP_API_DEBUG_KEY}" ]]; then
        sed -i '' 's/AIRSHIP_KEY=.*/AIRSHIP_KEY="${AIRSHIP_API_DEBUG_KEY}"/g' $WORKSPACE/Configuration/SecureKeys-Debug.xcconfig
    fi
    if [[ -n "${AIRSHIP_API_DEBUG_SECRET}" ]]; then
        sed -i '' 's/AIRSHIP_SECRET=.*/AIRSHIP_SECRET="${AIRSHIP_API_DEBUG_SECRET}"/g' $WORKSPACE/Configuration/SecureKeys-Debug.xcconfig
    fi
    if [[ -n "${APPSFLYER_DEV_KEY_DEBUG}" ]]; then
        sed -i '' 's/APPSFLYER_API_DEV_KEY=.*/APPSFLYER_API_DEV_KEY="${APPSFLYER_DEV_KEY_DEBUG}"/g' $WORKSPACE/Configuration/SecureKeys-Debug.xcconfig
    fi
    if [[ -n "${APPSFLYER_APP_ID_DEBUG}" ]]; then
        sed -i '' 's/APPSFLYER_API_APP_ID=.*/APPSFLYER_API_APP_ID="${APPSFLYER_APP_ID_DEBUG}"/g' $WORKSPACE/Configuration/SecureKeys-Debug.xcconfig
    fi
    if [[ -n "${APPSFLYER_ONELINK_AUTH_DEBUG}" ]]; then
        sed -i '' 's/APPSFLYER_ONELINK_API_AUTH=.*/APPSFLYER_ONELINK_API_AUTH="${APPSFLYER_ONELINK_AUTH_DEBUG}"/g' $WORKSPACE/Configuration/SecureKeys-Debug.xcconfig
    fi
    if [[ -n "${FLIPP_KEY_DEBUG}" ]]; then
        sed -i '' 's/FLIPP_API_KEY=.*/FLIPP_API_KEY="${FLIPP_KEY_DEBUG}"/g' $WORKSPACE/Configuration/SecureKeys-Debug.xcconfig
    fi
    if [[ -n "${FIS_PAYPAGEID_KEY_DEBUG}" ]]; then
        sed -i '' 's/FIS_PAYPAGEID_KEY=.*/FIS_PAYPAGEID_KEY="${FIS_PAYPAGEID_KEY_DEBUG}"/g' $WORKSPACE/Configuration/SecureKeys-Debug.xcconfig
    fi
     if [[ -n "${FIS_PAYPAGEID_PROD_KEY_DEBUG}" ]]; then
        sed -i '' 's/FIS_PAYPAGEID_PROD_KEY=.*/FIS_PAYPAGEID_PROD_KEY="${FIS_PAYPAGEID_PROD_KEY_DEBUG}"/g' $WORKSPACE/Configuration/SecureKeys-Debug.xcconfig
    fi
    if [[ -n "${ID_ME_CLIENT_ID}" ]]; then
        sed -i '' 's/ID_ME_CLIENT_ID_KEY=.*/ID_ME_CLIENT_ID_KEY="${ID_ME_CLIENT_ID}"/g' $WORKSPACE/Configuration/SecureKeys-Debug.xcconfig
    fi
     if [[ -n "${TSL_SHARED_SECRETE}" ]]; then
        sed -i '' 's/TSL_SECRETE=.*/TSL_SECRETE="${TSL_SHARED_SECRETE}"/g' $WORKSPACE/Configuration/SecureKeys-Debug.xcconfig
    fi
     if [[ -n "${TSL_DEV_SHARED_SECRETE}" ]]; then
        sed -i '' 's/TSL_SECRETE_DEV=.*/TSL_SECRETE_DEV="${TSL_DEV_SHARED_SECRETE}"/g' $WORKSPACE/Configuration/SecureKeys-Debug.xcconfig
    fi
     if [[ -n "${TSL_CLIENT_KEY}" ]]; then
        sed -i '' 's/TSL_KEY=.*/TSL_KEY="${TSL_CLIENT_KEY}"/g' $WORKSPACE/Configuration/SecureKeys-Debug.xcconfig
    fi
     if [[ -n "${TSL_DEV_CLIENT_KEY}" ]]; then
        sed -i '' 's/TSL_KEY_DEV=.*/TSL_KEY_DEV="${TSL_DEV_CLIENT_KEY}"/g' $WORKSPACE/Configuration/SecureKeys-Debug.xcconfig
    fi
    
     if [[ -n "${LIVESTREAM_SALT_KEY}" ]]; then
        sed -i '' 's/LIVESTREAM_SALT=.*/LIVESTREAM_SALT="${LIVESTREAM_SALT_KEY}"/g' $WORKSPACE/Configuration/SecureKeys-Debug.xcconfig
    fi
     if [[ -n "${LIVESTREAM_DEV_SALT_KEY}" ]]; then
        sed -i '' 's/LIVESTREAM_SALT_DEV=.*/LIVESTREAM_SALT_DEV="${LIVESTREAM_DEV_SALT_KEY}"/g' $WORKSPACE/Configuration/SecureKeys-Debug.xcconfig
    fi
    
    # Same id used for debug and release builds
    sed -i '' 's/CONSUMER_ID_KEY_DEBUG/${CONSUMER_ID_KEY}/g' $WORKSPACE/Configuration/SecureKeys-Debug.xcconfig
    fi
    if [[ -n "${APPCENTER_KEY_DEBUG}" ]]; then
        sed -i '' 's/APPCENTER_API_KEY=.*/APPCENTER_API_KEY="${APPCENTER_KEY_DEBUG}"/g' $WORKSPACE/Configuration/SecureKeys-Debug.xcconfig
    fi
    if [[ -n "${AR_API_CLIENT_KEY_DEBUG}" ]]; then
        sed -i '' 's/AR_API_CLIENT_KEY=.*/AR_API_CLIENT_KEY="${AR_API_CLIENT_KEY_DEBUG}"/g' $WORKSPACE/Configuration/SecureKeys-Debug.xcconfig
    fi
        if [[ -n "${AR_API_CLIENT_SECRET_KEY_DEBUG}" ]]; then
        sed -i '' 's/AR_API_CLIENT_SECRET_KEY=.*/AR_API_CLIENT_SECRET_KEY="${AR_API_CLIENT_SECRET_KEY_DEBUG}"/g' $WORKSPACE/Configuration/SecureKeys-Debug.xcconfig
    fi
    ## Update PRE_RELEASE XCCONFIG value for
        if [[ -n "${PRE_RELEASE}" ]]; then
        sed -i '' 's/DEBUG=.*/PRE_RELEASE=1/g' $WORKSPACE/Configuration/WalmartProject-Debug.xcconfig
        sed -i '' 's/SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG/SWIFT_ACTIVE_COMPILATION_CONDITIONS = PRE_RELEASE/g' $WORKSPACE/Configuration/WalmartProject-Debug.xcconfig
    fi

}

function check_carthage_version() {
    local carthage_version=$(mint run carthage version | xargs)
    echo "Carthage Version : ${carthage_version}"
}

function check_xcodeproj_installation() {
    local is_installed=$(gem list -i "^xcodeproj$")
    if [ $is_installed != true ]; then
        echo "**** Error: Looks like you do not have xcodeproj installed. ****";
        echo "Execute \`[sudo] gem install xcodeproj\` to install."
        exit 1;
    fi
    echo "Xcodeproj is installed"
}

function validate_carthage_dependencies() {
    local carthage_dependencies=$(mint run carthage validate)
    if [ "${carthage_dependencies}" != "No incompatibilities found in Cartfile.resolved" ]; then
        echo "This commit breaks the Carthage dependencies";
    else
        echo "Carthage dependencies look good"
    fi
}

function cleanup_carthage_projects() {
    ./scripts/cleanup-carthage-projects.rb

    if [[ -f "Carthage/Build/PerimeterX.framework/PerimeterX" ]]; then
        xcrun strip -x -arch x86_64 Carthage/Build/PerimeterX.framework/PerimeterX
    fi
}

# $1 == use bootstrap; $2 == use update; $3 == use submodules
function run_carthage() {
    carthage_cmd="mint run carthage "
    if [ $1 == 1 ]; then
        carthage_cmd="${carthage_cmd} bootstrap"
    elif [ $2 == 1 ]; then
        carthage_cmd="${carthage_cmd} update"
    else
        echo "Nothing to do"; exit 1
    fi

    if [ $3 == 1 ]; then
        carthage_cmd="${carthage_cmd} --use-submodules"
    fi

    carthage_cmd="${carthage_cmd} --no-build"

    if [ "$JENKINS_USER" ]; then
        if [ $GITHUB_TOKEN ]; then
            sed -i '' "s/git@gecgithub01.walmart.com:/https:\/\/${GITHUB_TOKEN}@gecgithub01.walmart.com\//g" ./Cartfile ./Cartfile.resolved;
        fi

        proxy_dependencies=$(cat Cartfile.resolved | egrep -o "github \"(.*?)\"" | sed 's#^github ".*/\(.*\)"$#\1#g' | tr '\n' ' ')
        noproxy_dependencies=$(cat Cartfile.resolved | egrep -o "git \"(.*?)\"" | sed 's#^git ".*/\(.*\).git"$#\1#g' | tr '\n' ' ')

        $carthage_cmd $proxy_dependencies
        http_proxy= https_proxy= mint run carthage bootstrap --no-build $noproxy_dependencies
    else
        $carthage_cmd
    fi

    #Bootstrap prebuilt dependecies
    if [ -e Cartfile.resolved ]; then
        cart_file="Cartfile.resolved"
    else
        cart_file="Cartfile"
    fi


    prebuilt_dependencies=$(
        cat ${cart_file} | \
        egrep -o "binary \".*\/([^\/]+.json)\"" | \
        sed 's#^binary.*\/\([^\/]*\)\.json"$#\1#g'
    )

    echo $prebuilt_dependencies

    for prebuilt_dependency in $prebuilt_dependencies
    do
        mint run carthage bootstrap --platform ios $prebuilt_dependency
    done

    # Validate Carthage dependencies
    validate_carthage_dependencies

    # Remove carthage schemes
    find "Carthage/" -name "xcschememanagement.plist" | xargs rm -rf
    find "Carthage/" -name "*.xcscheme" | xargs rm -rf
    find "Carthage/" -name "Package.swift" | xargs rm -rf
    find "Carthage/" -name ".swiftpm" | xargs rm -rf
    find "Carthage/" -name "*.resolved" | xargs rm -rf

    if [ $3 == 0 ]; then
        # Clean carthage dependencies
        cleanup_carthage_projects
    fi
}

function nuke_build_env() {
    echo "Quit Simulator"
    killall Simulator ||:
    pkill -9 -f Simulator ||:
    killall -9 com.apple.CoreSimulator.CoreSimulatorService ||:
    pkill -9 -f com.apple.CoreSimulator.CoreSimulatorService ||:
    echo "✔ Quit Simulator complete"

    if [ "$JENKINS_USER" ]; then
        echo "Reset Simulator"
        xcrun simctl erase all ||:
        echo "✔ Reset Simulator complete"
    else
        echo "Quit Xcode"
        killall Xcode ||:
        pkill -9 -f Xcode ||:
        echo "✔ Quit Xcode complete"

        rm -rf ~/Library/Developer/Xcode/DerivedData/*
    fi

    if [ "$(ls -A ~/Library/Caches/org.carthage.carthagekit/)" ]; then
        ls -d ~/Library/Caches/org.carthage.carthagekit/* | xargs rm -rf
    fi

    rm -rf ~/Library/Caches/carthage
    rm -rf ~/.rncache
    rm -rf ./Carthage

    echo "*** CLEANUP COMPLETE ***"
    echo "Run './scripts/carthage.sh' now if you want to grab the latest dependencies."
}

function eviscerate_build_env() {
    echo "Quit Simulator"
    killall Simulator ||:
    pkill -9 -f Simulator ||:
    killall -9 com.apple.CoreSimulator.CoreSimulatorService ||:
    pkill -9 -f com.apple.CoreSimulator.CoreSimulatorService ||:
    echo "✔ Quit Simulator complete"

    echo "Quit Xcode"
    killall Xcode ||:
    pkill -9 -f Xcode ||:
    echo "✔ Quit Xcode complete"

    rm -rf ~/Library/Developer/Xcode/DerivedData/*

    echo "Reset Simulator"
    xcrun simctl erase all ||:
    echo "✔ Reset Simulator complete"

    if [ "$(ls -A ~/Library/Caches/org.carthage.carthagekit/)" ]; then
        ls -d ~/Library/Caches/org.carthage.carthagekit/* | xargs rm -rf
    fi

    rm -rf ~/Library/Caches/carthage
    rm -rf ~/.rncache
    rm -rf ./Carthage
    git clean -fdx

    echo "*** EVISCERATE COMPLETE ***"
    echo "Run './scripts/carthage.sh' now if you want to grab the latest dependencies."
}
