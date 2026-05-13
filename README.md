# SignIt
SignIt is an advanced iOS application designed for digital image authentication and integrity. By leveraging digital watermarking, cryptographic signatures, and machine learning, the platform allows users to capture, sign, and verify the authenticity of visual content in an era of increasing digital manipulation.

## Features
 AI-Powered Watermarking: Integrates a custom CoreML model (AxiomoraEncoder) to embed robust digital watermarks into images.

 Cryptographic Signatures: A dedicated SignatureManager and WatermarkEmbedder system for attaching unique user identifiers to media.

 Verification Engine: Generates comprehensive VerificationReport data to validate whether an image has been tampered with or if it belongs to the original creator. This feature is yet to be completed.

 Custom Camera & Gallery: A bespoke CameraManager built on AVFoundation for high-quality capture, paired with a custom gallery for managing authenticated assets.

 Secure Onboarding: Complete authentication flow including user registration, login, and secure password management.

 Social Identity Integration: Allows users to link social platform handles to their digital signatures for cross-platform identity verification.

## Tech Stack
Language: Swift 5.x

UI Framework: UIKit (Storyboard & XIB architecture)

AI/ML: CoreML (.mlpackage) for watermark encoding.

Hardware Integration: AVFoundation (Camera) and Photos Framework.

Architecture: Organized using a modular feature-based approach (MVC/MVVM patterns).

## Project Structure
Axiomora/
├── Core/             # Business logic: Auth, Camera, Watermarking, and Signatures
├── Features/         # UI Modules: Camera, Gallery, Verification, and Settings
├── Data/             # Models (User, Image, VerificationReport) and Mock Services
├── Resources/        # UI Theme, Fluid backgrounds, and Strings
└── ZippableAssets/   # CoreML models and asset catalogs

## Installation
Clone the repository.
Open Axiomora.xcodeproj in Xcode.
Unzip the ZippableAssets.zip
Add the ZippableAssets folder under Resources folder.

Ensure you have a valid development team set for the target to use Camera and Photo Library capabilities.

Build and run on a physical iOS device for full camera functionality.

## Security & Privacy
Axiomora is built with a focus on user privacy. All image processing and watermark embedding are handled locally on-device using CoreML, ensuring that sensitive metadata and original content remain under the user's control.
