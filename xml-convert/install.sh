#!/bin/bash

echo "🚀 Installing MT5 XML Converter dependencies..."
echo "================================================"

# Check if npm is available
if ! command -v npm &> /dev/null; then
    echo "❌ npm is not installed. Please install Node.js first."
    exit 1
fi

# Try to fix npm cache permissions if needed
if [ -d "$HOME/.npm" ]; then
    echo "🔧 Checking npm cache permissions..."
    if [ ! -w "$HOME/.npm" ]; then
        echo "⚠️  Fixing npm cache permissions..."
        sudo chown -R $(id -u):$(id -g) "$HOME/.npm"
    fi
fi

# Clean npm cache
echo "🧹 Cleaning npm cache..."
npm cache clean --force

# Install dependencies
echo "📦 Installing dependencies..."
npm install

if [ $? -eq 0 ]; then
    echo "✅ Installation completed successfully!"
    echo ""
    echo "🎉 You can now use the converter:"
    echo "   npm run convert ReportOptimizer-shorter.xml"
    echo "   node cli.js stats ReportOptimizer-shorter.xml"
    echo "   node cli.js list"
else
    echo "❌ Installation failed. You may need to:"
    echo "   1. Fix npm permissions: sudo chown -R \$(id -u):\$(id -g) ~/.npm"
    echo "   2. Or install dependencies manually: npm install xml2js csv-writer fs-extra commander"
fi
