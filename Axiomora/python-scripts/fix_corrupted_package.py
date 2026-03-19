#!/usr/bin/env python3
"""
Fix Corrupted CoreML Package

This script reads the existing model.mlmodel file and re-saves it as a proper
.mlpackage with a valid Manifest.json.

Requirements:
    pip install coremltools

Usage:
    python fix_corrupted_package.py
"""

import os
import sys
import shutil
import json

def main():
    print("=" * 60)
    print("FIXING CORRUPTED COREML PACKAGE")
    print("=" * 60)
    
    # Try to import coremltools
    try:
        import coremltools as ct
    except ImportError:
        print("\n❌ ERROR: coremltools not installed")
        print("\nInstall it with:")
        print("  pip install coremltools")
        print("\nOr if using conda:")
        print("  conda install -c conda-forge coremltools")
        sys.exit(1)
    
    print(f"✓ coremltools version: {ct.__version__}")
    
    # Path to corrupted package
    package_path = "./MLAssets/AxiomarkEncoder.mlpackage"
    model_path = os.path.join(package_path, "Data/com.apple.CoreML/model.mlmodel")
    
    if not os.path.exists(model_path):
        print(f"\n❌ ERROR: Model file not found at {model_path}")
        print("\nMake sure you're running this from your Xcode project directory:")
        print("  cd /path/to/Axiomora")
        print("  python fix_corrupted_package.py")
        sys.exit(1)
    
    print(f"✓ Found model file: {model_path}")
    
    # Load the model with weights directory
    print("\nLoading model...")
    weights_dir = os.path.join(package_path, "Data/com.apple.CoreML/weights")
    
    try:
        # Try loading the package directly first
        model = ct.models.MLModel(package_path)
        print("✓ Model loaded successfully")
    except Exception as e:
        print(f"❌ Failed to load package: {e}")
        print("\nTrying to load .mlmodel with weights directory...")
        try:
            # Load model with weights directory
            model = ct.models.MLModel(model_path, weights_dir=weights_dir)
            print("✓ Model loaded from .mlmodel file with weights")
        except Exception as e2:
            print(f"❌ Failed to load .mlmodel: {e2}")
            print("\nThe model file itself appears to be corrupted.")
            print("You need to re-export from the training server.")
            sys.exit(1)
    
    # Create backup
    backup_path = package_path + ".backup"
    if os.path.exists(backup_path):
        print(f"\nRemoving old backup: {backup_path}")
        shutil.rmtree(backup_path)
    
    print(f"\nCreating backup: {backup_path}")
    shutil.copytree(package_path, backup_path)
    print("✓ Backup created")
    
    # Save as new package (this will generate proper Manifest.json)
    fixed_path = "./MLAssets/AxiomarkEncoder_FIXED.mlpackage"
    
    if os.path.exists(fixed_path):
        print(f"\nRemoving old fixed package: {fixed_path}")
        shutil.rmtree(fixed_path)
    
    print(f"\nSaving fixed package: {fixed_path}")
    
    # Save with weights directory if model is mlProgram
    try:
        # For mlProgram models, we need to specify weights_dir
        if hasattr(model, '_spec') and model._spec.WhichOneof('Type') == 'mlProgram':
            print("Model is mlProgram format - copying weights...")
            # Create the fixed package directory structure
            os.makedirs(os.path.join(fixed_path, "Data/com.apple.CoreML/weights"), exist_ok=True)
            
            # Copy weights
            src_weights = os.path.join(package_path, "Data/com.apple.CoreML/weights")
            dst_weights = os.path.join(fixed_path, "Data/com.apple.CoreML/weights")
            
            if os.path.exists(src_weights):
                shutil.copytree(src_weights, dst_weights, dirs_exist_ok=True)
                print("✓ Weights copied")
            
            # Save the model
            model.save(fixed_path)
        else:
            # Regular model, can save directly
            model.save(fixed_path)
    except Exception as e:
        print(f"❌ Failed to save: {e}")
        print("\nTrying alternative save method...")
        
        # Alternative: manually construct the package
        os.makedirs(os.path.join(fixed_path, "Data/com.apple.CoreML"), exist_ok=True)
        
        # Copy model.mlmodel
        shutil.copy2(
            os.path.join(package_path, "Data/com.apple.CoreML/model.mlmodel"),
            os.path.join(fixed_path, "Data/com.apple.CoreML/model.mlmodel")
        )
        
        # Copy weights directory
        src_weights = os.path.join(package_path, "Data/com.apple.CoreML/weights")
        dst_weights = os.path.join(fixed_path, "Data/com.apple.CoreML/weights")
        if os.path.exists(src_weights):
            shutil.copytree(src_weights, dst_weights, dirs_exist_ok=True)
        
        # Create proper Manifest.json
        manifest = {
            "fileFormatVersion": "1.0.0",
            "itemInfoEntries": {
                "0": {
                    "path": "Data/com.apple.CoreML",
                    "author": "com.apple.coreml",
                    "description": "CoreML Model",
                    "createdDate": "2025-03-19T00:00:00Z"
                }
            }
        }
        
        with open(os.path.join(fixed_path, "Manifest.json"), 'w') as f:
            json.dump(manifest, f, indent=2)
        
        print("✓ Package created manually with Manifest.json")
    
    print("✓ Fixed package saved")
    
    # Verify the fix
    print("\nVerifying fixed package...")
    required_files = [
        "Manifest.json",
        "Data/com.apple.CoreML/model.mlmodel"
    ]
    
    all_present = True
    for file_path in required_files:
        full_path = os.path.join(fixed_path, file_path)
        if os.path.exists(full_path):
            size = os.path.getsize(full_path)
            print(f"  ✓ {file_path} ({size:,} bytes)")
        else:
            print(f"  ❌ {file_path} MISSING!")
            all_present = False
    
    if all_present:
        print("\n✓ Fixed package is complete!")
    else:
        print("\n❌ Fixed package is still incomplete")
        sys.exit(1)
    
    # Instructions
    print("\n" + "=" * 60)
    print("SUCCESS! Package fixed.")
    print("=" * 60)
    print("\nNext steps:")
    print("1. In Xcode, remove the old AxiomarkEncoder.mlpackage from your project")
    print("2. Add the new AxiomarkEncoder_FIXED.mlpackage")
    print("3. Update WatermarkEmbedder.swift line 113:")
    print("   Change:")
    print('     forResource: "AxiomarkEncoder"')
    print("   To:")
    print('     forResource: "AxiomarkEncoder_FIXED"')
    print("\n4. Clean Build Folder (Cmd+Shift+K)")
    print("5. Delete Derived Data")
    print("6. Rebuild (Cmd+B)")
    print("=" * 60)


if __name__ == "__main__":
    main()
