#!/bin/bash

KNY-TRP() {
    echo "Program interrupted. Activating safe gate."
    trap '' INT TSTP

    if [ "$PROJECT_READY" -eq 1 ] && [ -d "$WORKING_DIR" ]; then
        ARCHIVE="${WORKING_DIR}_archive.zip"
        rm -f "$ARCHIVE"
        zip -r -q "$ARCHIVE" "$WORKING_DIR"
        echo "Incomplete project saved to $ARCHIVE"
        rm -rf "$WORKING_DIR"
        echo "Incomplete directory $WORKING_DIR removed."
    fi

    exit 1
}

PROJECT_READY=0
trap KNY-TRP INT TSTP

echo "Checking required tools and files"

if ! command -v python3 > /dev/null 2>&1; then
    echo "ERROR: python3 is not installed."
    exit 1
fi

if ! command -v zip > /dev/null 2>&1; then
    echo "ERROR: zip is not installed."
    exit 1
fi

for file in attendance_checker.py config.json assets.csv; do
    if [ ! -f "templates/$file" ]; then
        echo "ERROR: templates/$file is missing."
        exit 1
    fi
done

echo "All essentials are present."

read -p "Enter a project name (keep the name short): " name

WORKING_DIR="attendance_tracker_$name"

if [ -d "$WORKING_DIR" ]; then
    echo "Directory $WORKING_DIR already exists."
    read -p "Do you want to overwrite this directory $WORKING_DIR (y/n): " answer

    if [ "$answer" = "y" ] || [ "$answer" = "Y" ]; then
        rm -rf "$WORKING_DIR"
    else
        echo "Aborted. Nothing was changed."
        exit 1
    fi
fi

mkdir -p "$WORKING_DIR/Helpers" "$WORKING_DIR/reports"
PROJECT_READY=1

cp "templates/attendance_checker.py" "$WORKING_DIR/"
cp "templates/config.json" "$WORKING_DIR/Helpers/"

echo "Created $WORKING_DIR with Helpers/ and reports/."

echo ""
echo "How do you want to build the roster?"
echo "  A) Copy students from the template"
echo "  B) Generate new roster "
read -p "Choose A or B: " choice

ROSTER="$WORKING_DIR/Helpers/assets.csv"

if [ "$choice" = "A" ] || [ "$choice" = "a" ]; then
    total=$(tail -n +2 "templates/assets.csv" | grep -c .)

    read -p "How many students to copy (1-$total): " count

    if ! [[ "$count" =~ ^[0-9]+$ ]] || [ "$count" -lt 1 ] || [ "$count" -gt "$total" ]; then
        echo "ERROR: invalid number."
        exit 1
    fi

    head -n $((count + 1)) "templates/assets.csv" > "$ROSTER"
    echo "Copied $count students."

elif [ "$choice" = "B" ] || [ "$choice" = "b" ]; then
    read -p "How many students do you want to enter? " count

    if ! [[ "$count" =~ ^[0-9]+$ ]] || [ "$count" -lt 1 ]; then
        echo "ERROR: invalid number."
        exit 1
    fi

    echo "Email,Names,Attendance Count,Absence Count" > "$ROSTER"

    for (( i = 1; i <= count; i++ )); do
        read -p "Name of student $i: " student_name

        if [ -z "$student_name" ] || [[ "$student_name" == *,* ]]; then
            echo "ERROR: the name cannot be empty or contain a comma."
            exit 1
        fi

        email="$(echo "$student_name" | tr 'A-Z ' 'a-z.')@example.com"

        read -p "Attendance count for $student_name (0-4): " attendance

        if ! [[ "$attendance" =~ ^[0-9]+$ ]] || [ "$attendance" -gt 4 ]; then
            echo "ERROR: attendance must be a whole number from 0 to 4."
            exit 1
        fi

        absence=$(( 4 - attendance ))

        echo "$email,$student_name,$attendance,$absence" >> "$ROSTER"
        echo "  Added $student_name <$email> (attendance $attendance, absence $absence)"
    done

    echo "Created a roster with $count students."

else
    echo "ERROR: you must choose A or B."
    exit 1
fi

chmod +x "$WORKING_DIR/attendance_checker.py"
chmod 600 "$WORKING_DIR/Helpers/config.json"

echo "Permissions set:"
ls -l "$WORKING_DIR/attendance_checker.py" "$WORKING_DIR/Helpers/config.json"

echo ""
read -p "Do you want to update the alert thresholds? (y/n): " answer

if [ "$answer" = "y" ] || [ "$answer" = "Y" ]; then
    read -p "Warning threshold % (press Enter for 75): " warn
    read -p "Failure threshold % (press Enter for 50): " fail

    [ -z "$warn" ] && warn=75
    [ -z "$fail" ] && fail=50

    sed -i "s/\"warning\": *[0-9]*/\"warning\": $warn/" "$WORKING_DIR/Helpers/config.json"
    sed -i "s/\"failure\": *[0-9]*/\"failure\": $fail/" "$WORKING_DIR/Helpers/config.json"

    echo "Thresholds updated: warning=$warn, failure=$fail"
fi

trap - INT TSTP

echo ""
echo "Starting the attendance checker..."
echo "Mark each student as P (present) or A (absent)."
echo ""

(cd "$WORKING_DIR" && python3 attendance_checker.py)
APP_STATUS=$?

STAMP=$(date +%Y%m%d_%H%M%S)

ARCHIVES_DIR="$WORKING_DIR/archives"
ATTEND_ARCH_DIR="$ARCHIVES_DIR/attendance"
ABSENT_ARCH_DIR="$ARCHIVES_DIR/absent"

mkdir -p "$ATTEND_ARCH_DIR" "$ABSENT_ARCH_DIR"

if [ -s "$WORKING_DIR/reports/attendance.log" ]; then
    cp "$WORKING_DIR/reports/attendance.log" "$ATTEND_ARCH_DIR/attendance_$STAMP.log"
    echo "Archived: $ATTEND_ARCH_DIR/attendance_$STAMP.log"
else
    echo "log attendance.log not generated"
fi

if [ -s "$WORKING_DIR/reports/absent.log" ]; then
    cp "$WORKING_DIR/reports/absent.log" "$ABSENT_ARCH_DIR/absent_$STAMP.log"
    echo "Archived: $ABSENT_ARCH_DIR/absent_$STAMP.log"
else
    echo "log absent.log not generated"
fi

echo ""
if [ "$APP_STATUS" -eq 0 ]; then
    echo "Program ran successfully."
else
    echo "The attendance checker stopped with an error or was interrupted."
fi
echo "Archives folder: $ARCHIVES_DIR/"
exit "$APP_STATUS"
