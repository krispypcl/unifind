# Unifind (Perez_Prefinal)

An administrative web portal built with Flutter for managing the university's lost and found system. This portal serves as the centralized hub for processing, tracking, and resolving lost and found items across the campus.

## Overview

Unifind streamlines the process of managing lost items by providing a dedicated interface for administrators. It works seamlessly alongside the companion Unifind mobile application, sharing a unified database to ensure that reports submitted by students are instantly visible and manageable on the admin side.

## Key Features

* **Institutional Access Control**: Registration and authentication are strictly restricted to `@addu.edu.ph` accounts, ensuring that the admin dashboard is securely locked to authorized school personnel only.
* **Supabase Integration**: Powered by a Supabase backend for robust handling of authentication, real-time data syncing, and secure storage of item records.
* **Unified Ecosystem**: Shares identical database architecture and authentication logic with the student mobile app, allowing for perfect 1:1 synchronization between admin operations and student claims.

## Tech Stack

* **Frontend**: Flutter (Web)
* **Backend/Database**: Supabase
* **Language**: Dart

## Getting Started

### Prerequisites

* [Flutter SDK](https://docs.flutter.dev/get-started/install) (latest stable version)
* A configured Supabase project (with appropriate URL and Anon Key)

### Installation

   ```bash
   git clone [https://github.com/krispypcl/unifind.git](https://github.com/krispypcl/unifind.git)
   cd unifind
   flutter pub get
   flutter run -d chrome --web-port 3000
