#!/bin/bash

# CONFIGURATION
API_KEY="YOUR API KEY"
API_URL="https://www.groundctl.com/api/v1/devices/find/all?api_key=$API_KEY"
INPUT_FILE="/File Location/devices_output.json"

# --------------------------------
# Check Internet Connectivity
# --------------------------------
echo "🌐 Checking internet connectivity..."
if ! ping -c 1 -W 1 google.com >/dev/null 2>&1; then
    echo "❌ No internet connection detected. Aborting script."
    exit 1
fi
echo "✅ Internet connection OK. Continuing..."

echo "Calling GroundControl API..."
#curl -X GET "$API_URL" -H "accept: application/json" -o $INPUT_FILE
curl --connect-timeout 60 --max-time 600 --retry 5 --retry-delay 5 --compressed -o $INPUT_FILE -X GET "$API_URL" -H "accept: application/json"

echo "Response saved to devices_output.json"
# Check for jq
if ! command -v jq >/dev/null 2>&1; then
    echo "Error: jq is not installed. Install with 'brew install jq'"
    exit 1
fi

# Check file exists
if [ ! -f "$INPUT_FILE" ]; then
    echo "Error: File $INPUT_FILE not found."
    exit 1
fi

echo "🔄 Parsing devices with Device Checkout Status of Checked Out, Checked In, or Overdue..."

# Initialize counters
checked_in=0
checked_out=0
overdue=0
failed=0

# Process each device (no subshell!)
while read -r device; do
    serial=$(echo "$device" | jq -r '.serial')
    name=$(echo "$device" | jq -r '.name')
    model=$(echo "$device" | jq -r '.model')
    status=$(echo "$device" | jq -r '.checkout_status')

    echo "Serial: $serial"
    echo "Name: $name"
    echo "Model: $model"
    echo "Device Checkout Status: $status"
    echo "---"

    # Increment category counter
    case "$status" in
        "Checked In") ((checked_in++)) ;;
        "Checked Out") ((checked_out++)) ;;
        "Overdue") ((overdue++)) ;;
        "Failed") ((failed++)) ;;
    esac
done < <(jq -c '
.[] 
| { serial: .serial, name: .name, model: .modelName, 
    checkout_status: (.customFieldValues[]? 
                      | select(.name == "Device Checkout Status" 
                               and (.value == "Checked Out" 
                                    or .value == "Checked In" 
                                    or .value == "Failed" 
                                    or .value == "Overdue")) 
                      | .value)
}
| select(.checkout_status != null)
' "$INPUT_FILE")

# Prepare totals
totals="✅Checked In: $checked_in\n☑️Checked Out: $checked_out\n❓Overdue: $overdue\n❌Failed: $failed"

# Output to terminal
echo "Totals:"
echo -e "$totals"

# Show dialog box
osascript -e "display dialog \"✅ $checked_in Checked In\n☑️ $checked_out Checked Out\n❓ $overdue Overdue\n❌ $failed Failed\" with title \"GroundControl Device Monitor\" buttons {\"OK\"} default button \"OK\""
