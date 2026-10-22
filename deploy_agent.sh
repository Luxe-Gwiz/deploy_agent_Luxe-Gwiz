#!/bin/bash



KNY-TRP() {
    echo "Program interrupted. Activating safe gate."
    trap '' INT TSTP
    if [ "$READY" -eq 1 ] && [ -d "$WORKING_DIR" ]; then
        [ -f "$WORKING_DIR.zip" ] || zip -qr "$WORKING_DIR.zip" "$WORKING_DIR"
        rm -rf "$WORKING_DIR"
    fi
    exit 1
}
trap KNY-TRP INT TSTP

check() {
    command -v python3 >/dev/null || { echo "ERROR: python3 not installed."; exit 1; }
    command -v zip >/dev/null || { echo "ERROR: zip not installed."; exit 1; }
    for f in attendance_checker.py config.json assets.csv; do
        [ -f "templates/$f" ] || { echo "ERROR: templates/$f missing."; exit 1; }
    done
    echo "All essentials present."
}

make_folders() {
    WORKING_DIR="attendance_tracker_$1"
    if [ -d "$WORKING_DIR" ]; then
        read -p "$WORKING_DIR exists. Overwrite? (y/n): " ans
        [[ "$ans" =~ ^[Yy]$ ]] || { echo "Aborted. Nothing was changed."; exit 1; }
        rm -rf "$WORKING_DIR"
    fi
    mkdir -p "$WORKING_DIR/Helpers" "$WORKING_DIR/reports"
    READY=1
    cp templates/attendance_checker.py "$WORKING_DIR/"
    cp templates/config.json "$WORKING_DIR/Helpers/"
}

build_roster() {
    local roster="$WORKING_DIR/Helpers/assets.csv"
    echo "  A) Copy from template"
    echo "  B) Generate new roster"
    read -p "Choose A or B: " choice
    case "$choice" in
        A|a)
            total=$(tail -n +2 templates/assets.csv | grep -c .)
            read -p "How many students (1-$total): " n
            [[ "$n" =~ ^[0-9]+$ && "$n" -ge 1 && "$n" -le "$total" ]] || { echo "ERROR: invalid number."; exit 1; }
            head -n $((n + 1)) templates/assets.csv > "$roster"
            ;;
        B|b)
            read -p "How many students? " n
            [[ "$n" =~ ^[0-9]+$ && "$n" -ge 1 ]] || { echo "ERROR: invalid number."; exit 1; }
            echo "Email,Names,Attendance Count,Absence Count" > "$roster"
            for (( i = 1; i <= n; i++ )); do
                read -p "Name of student $i: " name
                [[ -n "$name" && "$name" != *,* ]] || { echo "ERROR: bad name."; exit 1; }
                read -p "Attendance for $name (0-4): " att
                [[ "$att" =~ ^[0-4]$ ]] || { echo "ERROR: attendance must be 0-4."; exit 1; }
                email=$(echo "$name" | tr 'A-Z ' 'a-z.')@example.com
                echo "$email,$name,$att,$((4 - att))" >> "$roster"
            done
            ;;
        *) echo "ERROR: choose A or B."; exit 1 ;;
    esac
}

set_thresholds() {
    read -p "Update alert thresholds? (y/n): " ans
    [[ "$ans" =~ ^[Yy]$ ]] || return
    read -p "Warning % (Enter for 75): " warn
    read -p "Failure % (Enter for 50): " fail
    warn=${warn:-75}
    fail=${fail:-50}
    sed -i -e "s/\"warning\": *[0-9]*/\"warning\": $warn/" \
           -e "s/\"failure\": *[0-9]*/\"failure\": $fail/" \
           "$WORKING_DIR/Helpers/config.json"
}

archive_logs() {
    local stamp
    stamp=$(date +%Y%m%d_%H%M%S)
    mkdir -p "$WORKING_DIR/archives"
    for log in attendance absent; do
        src="$WORKING_DIR/reports/$log.log"
        if [ -s "$src" ]; then
            cp "$src" "$WORKING_DIR/archives/${log}_$stamp.log"
            echo "Archived $log.log"
        else
            echo "No $log.log was generated."
        fi
    done
}

check
read -p "Enter a project name (keep it short): " name
make_folders "$name"
build_roster
chmod +x "$WORKING_DIR/attendance_checker.py"
chmod 600 "$WORKING_DIR/Helpers/config.json"
set_thresholds

trap - INT TSTP
echo "Starting the attendance checker..."
(cd "$WORKING_DIR" && python3 attendance_checker.py)
status=$?

archive_logs

if [ "$status" -eq 0 ]; then
    echo "Program ran successfully."
else
    echo "The checker stopped with an error or was interrupted."
fi
