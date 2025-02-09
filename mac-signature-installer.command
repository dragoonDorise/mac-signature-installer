#!/bin/bash
# --------------------------------------------------------------------------------
# The MIT License (MIT)
# Copyright (c) 2016-2017 Cloud Under Ltd (https://cloudunder.io)
#
# Permission is hereby granted, free of charge, to any person obtaining a copy of
# this software and associated documentation files (the "Software"), to deal in
# the Software without restriction, including without limitation the rights to
# use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
# the Software, and to permit persons to whom the Software is furnished to do so,
# subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
# FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
# COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
# IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
# CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
# --------------------------------------------------------------------------------

RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
PURPLE="\033[0;35m"
CYAN="\033[0;36m"
GREY="\033[1;30m"
NC="\033[0m"
TAG_ERROR="${RED}[Error]${NC}"
TAG_WARNING="${YELLOW}[Warning]${NC}"
TAG_SUCCESS="${GREEN}[Success]${NC}"
TAG_INFO="${CYAN}[Info]${NC}"
UNLUCKY_MESSAGE="The signature may have to be installed differently."

# ------------------------------------------------------------------------------
FIXED_SIGNATURE_NAME=""
# ------------------------------------------------------------------------------
read -r -d '' RAW_SIGNATURE << EndOfStaticRawSignature
EndOfStaticRawSignature
# ------------------------------------------------------------------------------

clear
echo -ne "${GREY}"
cat << EOM
Email Signature Installer for Mail.app (macOS)
Version 0.2.0 - Copyright (c) 2017 Cloud Under Ltd

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
--------------------------------------------------------------------------------
EOM
echo -e "${NC}"

if [ "$(sw_vers -productName)" != "macOS" ]; then
	echo "This installer is only compatible with Mail for Mac OS X or macOS."
	exit 4
fi

OS_X_VERSION=$(sw_vers -productVersion | awk -F '.' '{print $2}')
if [ "${OS_X_VERSION}" -gt "13" ]; then
	echo -e "${TAG_WARNING} You are using this installer on macOS newer than 10.13 (High Sierra), the version this installer was made for. It may or may not still work."
	echo ""
fi

if [ -z "${RAW_SIGNATURE}" ]; then
	SIGNATURE_FILE="$1"

	if [ -z "${SIGNATURE_FILE}" ] || [ ! -f "${SIGNATURE_FILE}" ]; then
		echo -e "${TAG_ERROR} Signature file not found. Please provide the filename of the signature file as first argument. Example:"
		echo "./mac-installer.command ~/Downloads/filename.mailsignature"
		exit 1
	fi

	RAW_SIGNATURE=$(<"${SIGNATURE_FILE}")
fi

if ! grep -q -E "^Mime-Version: 1.0" <<< "${RAW_SIGNATURE}"; then
	if ! grep -q -E "</body>" <<< "${RAW_SIGNATURE}"; then
		echo -e "${TAG_ERROR} The file provided seems to be neither a signature nor a HTML file."
		exit 2
	fi

	echo -e "${TAG_INFO} Converting signature into MIME format."
	MESSAGE_HASH=$(openssl dgst -sha1 <<< "${RAW_SIGNATURE}" | tr '[:lower:]' '[:upper:]')
	MESSAGE_ID="07FBF600-${MESSAGE_HASH:0:4}-${MESSAGE_HASH:4:4}-${MESSAGE_HASH:8:4}-${MESSAGE_HASH:12:12}"
	read -r -d '' RAW_SIGNATURE << EndOfFormattedSignature
Content-Transfer-Encoding: quoted-printable
Content-Type: text/html;
	charset=utf-8
Message-Id: <${MESSAGE_ID}>
Mime-Version: 1.0

$(perl -MMIME::QuotedPrint -pe '$_=MIME::QuotedPrint::encode($_);' <<< "${RAW_SIGNATURE}")

EndOfFormattedSignature
fi

V="10"
MAIL_DIR="${HOME}/Library/Mail/V${V}/MailData/Signatures"
if [ ! -d "${MAIL_DIR}" ] || [ ! -f "${MAIL_DIR}/AllSignatures.plist" ]; then
	V="4"
	MAIL_DIR="${HOME}/Library/Mail/V${V}/MailData/Signatures"
	if [ ! -d "${MAIL_DIR}" ] || [ ! -f "${MAIL_DIR}/AllSignatures.plist" ]; then
		V="3"
		MAIL_DIR="${HOME}/Library/Mail/V${V}/MailData/Signatures"
		if [ ! -d "${MAIL_DIR}" ] || [ ! -f "${MAIL_DIR}/AllSignatures.plist" ]; then
			V="2"
			MAIL_DIR="${HOME}/Library/Mail/V${V}/MailData/Signatures"
			if [ ! -d "${MAIL_DIR}" ] || [ ! -f "${MAIL_DIR}/AllSignatures.plist" ]; then
				echo -e "${TAG_ERROR} I was unable to find your MailData directory on your system. ${UNLUCKY_MESSAGE}"
				exit 3
			fi
		fi
	fi
fi
ALL_SIG_FILE="${MAIL_DIR}/AllSignatures.plist"



if [ ! -x "/usr/libexec/PlistBuddy" ]; then
	echo -e "${TAG_ERROR} A system utility required by this installer could not be found. ${UNLUCKY_MESSAGE}"
	exit 4
fi

echo -e "${TAG_INFO} You can cancel this installer at any time by pressing Ctrl + C or by closing the Terminal window.\n"

if [ -z "${FIXED_SIGNATURE_NAME}" ]; then
	echo -e "Please open the Mail app, go to the app's preferences (Cmd + ,) and select the \"Signatures\" tab. Find a signature you want to replace or add a new signature by clicking the [+] button and give it a unique name. Don't change the signature itself, but make sure the checkbox \"Always match my default message font\" is NOT checked.\n"
	echo "Please enter the name of the signature you want to replace and press Enter."
fi

SIG_DATA=""
while [ -z "${SIG_DATA}" ]; do
	if [ -z "${FIXED_SIGNATURE_NAME}" ]; then
		echo -ne "${PURPLE}Signature name:${NC} "
		read SIGNATURE_NAME
	else
		SIGNATURE_NAME="${FIXED_SIGNATURE_NAME}"
	fi
	INDEX=0
	EXIT_CODE="0"
	SIG_DATA=""
	while [ "${EXIT_CODE}" -eq "0" ]; do
		SIG_DATA=""
		SIG_DATA=$(/usr/libexec/PlistBuddy -c "Print :${INDEX}" "${ALL_SIG_FILE}" 2>/dev/null | grep "Signature")
		EXIT_CODE=$?
		if [ ! -z "${SIG_DATA}" ]; then
			if grep -q "SignatureName = ${SIGNATURE_NAME}$" <<< "${SIG_DATA}"; then
				break
			fi
		fi
		INDEX=$((${INDEX} + 1))
	done
	if [ -z "${SIG_DATA}" ]; then
		if [ -z "${FIXED_SIGNATURE_NAME}" ]; then
			echo -e "${TAG_WARNING} Could not find a signature with the name \"${SIGNATURE_NAME}\". Please double-check the spelling and try again."
		else
			echo -e "${TAG_WARNING} Could not find a signature with the name \"${SIGNATURE_NAME}\"."
			echo -e "Please open the Mail app, go to the app's preferences (Cmd + ,) and select the \"Signatures\" tab. Add a new signature by clicking the [+] button and name it \"${CYAN}${SIGNATURE_NAME}${NC}\". Don't change the signature itself, but make sure the checkbox \"Always match my default message font\" is NOT checked."
			echo -ne "${PURPLE}When you're ready, press Enter to try again...${NC} "
			read
		fi
	fi
done


SIG_ID=$(grep "SignatureUniqueId = " <<< "${SIG_DATA}" | egrep -o "[0-9A-F-]{36}")
SYSTEM_SIG_FILE="${MAIL_DIR}/${SIG_ID}.mailsignature"
`grep -q "SignatureIsRich = true" <<< "${SIG_DATA}" &> /dev/null`
let "IS_RICH = ! $?"

if [ -z "${SIG_ID}" ]; then
	# Unable to extract SignatureUniqueId
	echo -e "${TAG_ERROR} Please contact support and quote error number 5. ${UNLUCKY_MESSAGE}"
	exit 5
fi

if [ ! -f "${SYSTEM_SIG_FILE}" ]; then
	# Signature file not found
	echo -e "${TAG_ERROR} If your signature \"${SIGNATURE_NAME}\" is empty, please enter a few random letters and try again. If that doesn't help, please contact support and quote error number 6. ${UNLUCKY_MESSAGE}"
	exit 6
fi

if [ ${IS_RICH} -ne 1 ]; then
	# Signature is not flagged as "rich"
	echo -e "${TAG_ERROR} Please UNCHECK the checkbox \"Always match my default message font\" for the signature \"${SIGNATURE_NAME}\", close the preferences window of Mail and then try again."
	exit 7
fi

if [ ! -z "${FIXED_SIGNATURE_NAME}" ]; then
	echo -e "\n\n${TAG_WARNING} If you continue now, the signature named \"${SIGNATURE_NAME}\" will be replaced with a new signature!"
	echo -ne "${PURPLE}Press Enter to continue...${NC} "
	read
fi

`killall -d "Mail" &> /dev/null`
let "MAIL_IS_RUNNING = ! $?"
if [ ${MAIL_IS_RUNNING} -eq 1 ]; then
	echo -ne "\n\n${PURPLE}Please quit the Mail app now.${NC} I'll wait (you can still cancel with Ctrl + C)"
	while [ ${MAIL_IS_RUNNING} -eq 1 ]; do
		echo -n "."
		sleep 1
		`killall -d "Mail" &> /dev/null`
		let "MAIL_IS_RUNNING = ! $?"
	done
fi

cat > "${SYSTEM_SIG_FILE}" <<< "${RAW_SIGNATURE}"
if [ $? -ne 0 ]; then
	echo -e "${TAG_ERROR} I was unable to install the signature file. Please make sure signature files are not locked. If you contact support, please quote error number 8."
	exit 8
fi

CLOUD_V="5"
CLOUD_DIR="${HOME}/Library/Mobile Documents/com~apple~mail/Data/V${CLOUD_V}/Signatures"
if [ ! -d "${CLOUD_DIR}" ] || [ ! -f "${CLOUD_DIR}/AllSignatures.plist" ]; then
	CLOUD_V="4"
	CLOUD_DIR="${HOME}/Library/Mobile Documents/com~apple~mail/Data/V${CLOUD_V}/Signatures"
	if [ ! -d "${CLOUD_DIR}" ] || [ ! -f "${CLOUD_DIR}/AllSignatures.plist" ]; then
		CLOUD_V="3"
		CLOUD_DIR="${HOME}/Library/Mobile Documents/com~apple~mail/Data/V${CLOUD_V}/Signatures"
		if [ ! -d "${CLOUD_DIR}" ] || [ ! -f "${CLOUD_DIR}/AllSignatures.plist" ]; then
			CLOUD_V="2"
			CLOUD_DIR="${HOME}/Library/Mobile Documents/com~apple~mail/Data/V${CLOUD_V}/Signatures"
			if [ ! -d "${CLOUD_DIR}" ] || [ ! -f "${CLOUD_DIR}/AllSignatures.plist" ]; then
				CLOUD_DIR=""
			fi
		fi
	fi
fi

if [ ! -z "${CLOUD_DIR}" ]; then
	CLOUD_SIG_FILE="${CLOUD_DIR}/${SIG_ID}.mailsignature"
	if [ -f "${CLOUD_SIG_FILE}" ]; then
		cat > "${CLOUD_SIG_FILE}" <<< "${RAW_SIGNATURE}"
		if [ $? -ne 0 ]; then
			echo -e "${TAG_ERROR} I was unable to install the signature file for iCloud. Please make sure signature files are not locked. If you contact support, please quote error number 9."
			exit 9
		fi
	fi
fi

echo -e "\n\n${TAG_SUCCESS} All done. Please start the Mail app and check if the signature with the name \"${SIGNATURE_NAME}\" has been updated correctly.\n\n"
