# 📦 UPS Application Suite

<div align="center">

![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Firebase](https://img.shields.io/badge/Firebase-039BE5?style=for-the-badge&logo=Firebase&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)
![Material Design](https://img.shields.io/badge/Material%20Design-757575?style=for-the-badge&logo=material-design&logoColor=white)

**A comprehensive digital postal service platform built with Flutter & Firebase**

[🌐 Live Admin Panel](https://ups-app-7d001.web.app) • [📱 Demo](#demo) • [📖 Documentation](#documentation) • [🚀 Quick Start](#quick-start)

</div>

---

## 🎯 Overview

The UPS Application Suite is a modern, full-stack digital postal service platform consisting of:

- **📱 Mobile Application** - Customer-facing Flutter app for iOS, Android & Web
- **🌐 Admin Panel** - Web-based administrative interface for service management
- **🔥 Firebase Backend** - Scalable cloud infrastructure with real-time capabilities

### ✨ Key Highlights

- 🔐 **Secure Authentication** with Firebase Auth & Google Sign-In
- 📍 **Real-time Package Tracking** with GPS integration
- 💰 **Integrated Payment System** for taxes and services
- 📊 **Comprehensive Admin Dashboard** with live analytics
- 🎯 **Complaint Management** with priority handling
- 📰 **Content Management** for news and updates
- 🌐 **Progressive Web App** capabilities
- 📱 **Responsive Design** across all devices

---

## 🚀 Quick Start

### Prerequisites

- Flutter SDK (3.9.0+)
- Firebase CLI
- Node.js (16.0+)
- Git

### Installation

```bash
# Clone repository
git clone https://github.com/vibodhalakshan2004/myapp.git
cd myapp

# Install dependencies
flutter pub get

# Configure Firebase
flutterfire configure

# Run mobile app
flutter run

# Run admin panel
cd admin_web
flutter run -d chrome
