#!/bin/bash
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Software distributed under the License is distributed on an "AS IS" basis,
# WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License for
# the specific language governing rights and limitations under the License.

set -e

FILE="$(realpath "${1:-/usr/lib/firefox/omni.ja}")"

optimizejars() {
    python3 /usr/lib/firefox-tweak/optimizejars.py "$@"
}

WORKDIR="$(mktemp -d -t "firefox-tweak.XXXXXX")"
trap "rm -r '$WORKDIR'" EXIT
pushd "$WORKDIR" >/dev/null

echo -n "Copying '$FILE'..."
cp "$FILE" omni.ja
echo "done"

echo -n "Deoptimizing 'omni.ja'..."
optimizejars --deoptimize ./ ./ ./ >/dev/null
echo "done"

echo -n "Extracting files from 'omni.ja'..."
unzip -qq omni.ja modules/AppConstants.jsm modules/addons/AddonSettings.jsm
echo "done"

replace() {
    local file="$1"
    local section="$2"
    local before="$3"
    local after="$4"

    awk -f - "$file" <<EOF > "$file".updated
found && /^\s*$before/ {
  sub("$before", "$after");
  found=0;
}

/$section/ { found=1; }

{ print; }
EOF
    mv "$file.updated" "$file"
}

echo -n "Setting MOZ_REQUIRE_SIGNING to false..."
replace modules/AppConstants.jsm MOZ_REQUIRE_SIGNING "true," "false,"
echo "done"

echo -n "Setting REQUIRE_SIGNING to false..."
replace modules/addons/AddonSettings.jsm "makeConstant\(\"REQUIRE_SIGNING\"" "true" "false"
echo "done"


echo -n "Disabling spyware..."
replace modules/AppConstants.jsm MOZ_TELEMETRY_REPORTING "true," "false,"
replace modules/AppConstants.jsm MOZ_SERVICES_HEALTHREPORT "true," "false,"
replace modules/AppConstants.jsm MOZ_DATA_REPORTING "true," "false,"
echo "done"

echo -n "Repacking 'omni.ja'..."
zip --quiet -9 -u omni.ja modules/AppConstants.jsm modules/addons/AddonSettings.jsm
echo "done"

echo -n "Optimizing 'omni.ja'..."
optimizejars --optimize ./ ./ ./ >/dev/null
echo "done"

popd >/dev/null

echo "Installing modified 'omni.ja'."
cp "$WORKDIR/omni.ja" "$FILE"
echo "All Done!"

exit 0
