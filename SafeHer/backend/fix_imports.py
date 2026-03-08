"""
Fix Import Statements
This script fixes all the import statements in your route files
Run this from the backend folder: python fix_imports.py
"""

import os
import re

def fix_file_imports(filepath):
    """Fix imports in a single file"""
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
        
        original_content = content
        
        # Fix backend.services imports
        content = re.sub(
            r'from backend\.services\.',
            'from services.',
            content
        )
        
        # Fix backend.database imports
        content = re.sub(
            r'from backend\.database\.',
            'from database.',
            content
        )
        
        # Fix any other backend. imports
        content = re.sub(
            r'from backend\.',
            'from ',
            content
        )
        
        # Only write if content changed
        if content != original_content:
            with open(filepath, 'w', encoding='utf-8') as f:
                f.write(content)
            return True
        return False
        
    except Exception as e:
        print(f"Error processing {filepath}: {e}")
        return False

def main():
    """Fix all route and service files"""
    print("🔧 Fixing import statements in Safe Her Travel backend...\n")
    
    fixed_files = []
    
    # Directories to fix
    directories = ['routes', 'services']
    
    for directory in directories:
        if not os.path.exists(directory):
            print(f"⚠️ Directory '{directory}' not found, skipping...")
            continue
            
        print(f"📁 Checking {directory}/ folder...")
        
        for filename in os.listdir(directory):
            if filename.endswith('.py') and not filename.startswith('__'):
                filepath = os.path.join(directory, filename)
                if fix_file_imports(filepath):
                    fixed_files.append(filepath)
                    print(f"  ✓ Fixed: {filepath}")
    
    print(f"\n✅ Import fixing complete!")
    print(f"📊 Fixed {len(fixed_files)} file(s)")
    
    if fixed_files:
        print("\nFixed files:")
        for f in fixed_files:
            print(f"  - {f}")
    
    print("\n🎯 You can now run: python app.py")

if __name__ == '__main__':
    # Check if we're in the backend folder
    if not os.path.exists('routes') or not os.path.exists('services'):
        print("❌ Error: Please run this script from the backend folder")
        print("   Usage: cd backend && python fix_imports.py")
    else:
        main()