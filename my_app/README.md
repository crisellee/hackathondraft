# Student Concern Management System

A Flutter-based web system for managing student concerns with auto-routing, SLA enforcement, and admin reporting.

## Key Features

- **Student Submission Portal**: 
    - Categories: Academic, Financial, Welfare.
    - **Auto-Routing**: Academic concerns are routed based on the student's program (e.g., STEM vs Humanities).
    - **Anonymity**: Toggle to hide student identity from departments.
- **Workflow & Status**:
    - Statuses: Submitted → Routed → Read → Screened → Resolved/Escalated.
    - **SLA Enforcement**: Auto-escalate if >2 days no read, >5 days no screening.
- **Admin Dashboard**:
    - **Real-time Metrics**: Tracks Average Resolution Time and Escalation Rate.
    - **Audit Trail**: Every action is logged with timestamp and actor.
    - **Export**: Generate CSV reports for departmental audits.

## Project Structure

- `lib/models.dart`: Data models for Concerns and Audit entries.
- `lib/concern_service.dart`: Business logic, SLA monitoring, and mock data generation.
- `lib/main.dart`: UI for the Student Portal and Admin Dashboard.

## Success Metrics

- Initialized with 50+ mock concerns.
- Targets <10% escalation rate.

## Getting Started

1. Ensure you have Flutter installed.
2. Run `flutter pub get` to install dependencies.
3. Run `flutter run -d chrome` to launch the web application.

## Usage

- **Submit**: Use the "Submit Concern" tab to enter new data.
- **Manage**: Switch to "Admin Dashboard" to view and update concern statuses.
- **SLA Audit**: Click the **Alarm Icon** in the dashboard to trigger the SLA scanner.
- **Report**: Click the **Download Icon** to view the CSV export.
