# Project Blueprint

## Overview

This document outlines the architecture, features, and design of the TrackWaste Flutter application. The app is designed to provide a comprehensive solution for waste management, including features for tracking waste, paying taxes, and booking waste collection services.

## Style, Design, and Features

### Initial Version

*   **Authentication:** Firebase-based authentication with email/password and Google Sign-In.
*   **Routing:** Declarative routing using the `go_router` package.
*   **State Management:** `provider` package for state management, including an `AuthService`.
*   **Theming:** Centralized theme management in `core/theme.dart` with separate light and dark themes.
*   **Core Features:** Placeholder screens for the main application features.

### Visual Overhaul & Theming Update

*   **Logo Integration:**
    *   Added the company logo to `assets/images/logo.png`.
    *   The logo is now prominently displayed on the authentication screens.
*   **Modern Theme:**
    *   The entire application theme has been updated in `lib/core/theme.dart`.
    *   The new theme uses a color palette derived from the logo (Primary Yellow: `#FBC02D`, Secondary Green: `#388E3C`).
    *   Switched to the modern and clean `Poppins` font from Google Fonts for all text styles.
*   **UI Redesign (Authentication):**
    *   The **Login** (`lib/features/auth/auth_screen.dart`) and **Registration** (`lib/features/auth/registration_screen.dart`) screens have been completely redesigned.
    *   Implemented a modern, clean, card-based layout centered on the screen.
    *   Improved user experience with loading indicators during asynchronous operations and better error message handling.

## Current Plan: Apply New Theme to Core App Screens

*   **Goal:** Extend the new modern UI and theme to all the core screens of the application beyond the authentication flow.
*   **Steps:**
    1.  Update the `DashboardScreen` to use the new theme's components and layout principles.
    2.  Redesign the `HomeScreen` to reflect the new visual identity.
    3.  Apply the updated styles to the `TaxPaymentScreen`, `WasteTrackerScreen`, `BookingsScreen`, and `ProfileScreen`.
    4.  Ensure consistent use of colors, fonts, and spacing across all screens.
