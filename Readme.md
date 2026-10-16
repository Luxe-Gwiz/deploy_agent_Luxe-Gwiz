# attendance_tracker

## Introduction

This program tracks student attendance. It consists of a Python program and a Bash script.

The Python program decides whether each student passes or fails, using the attendance records. The Bash script supplies and manages those records and prepares the project for the Python program.

The records are stored in `Helpers/assets.csv`, which holds each student's past attendance. `Helpers/config.json` provides the thresholds the Python program uses to decide pass or fail.

## How to Run the Script

```bash
chmod +x deploy_agent.sh
./deploy_agent.sh
```

Enter a project name like `v1` when prompted. The script must sit next to the `templates/` folder.

## What the Script Does

**Feature 1: Deploy the Application**

The script checks the required tools, creates the project folders, builds the roster, sets permissions, sets the thresholds, and starts the attendance checker.

**Feature 2: Protect and Organize the Work**

The script protects unfinished work by archiving it if you interrupt setup. After each run, it copies the logs into timestamped archive folders and keeps the originals in `reports/`.

##  Archive unfinished-Work

Press Ctrl+C or Ctrl+Z before the attendance checker starts. The script zips the incomplete folder into `attendance_tracker_{name}_archive.zip` and removes it.

Once the attendance checker starts, Ctrl+C is handled by the Python program.

## Log Archive Layout

```
attendance_tracker_{name}/
└── archives/
    ├── attendance/
    │   └── attendance_20260927_143022.log
    └── absent/
        └── absent_20260927_143022.log
```

If a log is missing or empty, the script prints a message and skips it.

## How to Run the Attendance App

```bash
cd attendance_tracker_v1
python3 attendance_checker.py
```
