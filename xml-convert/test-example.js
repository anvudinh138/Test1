// Simple test without dependencies to show the project structure
const fs = require('fs');
const path = require('path');

console.log('🚀 MT5 XML Converter Project Structure');
console.log('═'.repeat(50));

// Check if files exist
const files = [
    'package.json',
    'converter.js', 
    'cli.js',
    'index.js',
    'README.md',
    '.gitignore',
    'export/.gitkeep'
];

files.forEach(file => {
    const filePath = path.join(__dirname, file);
    const exists = fs.existsSync(filePath);
    const status = exists ? '✅' : '❌';
    console.log(`${status} ${file}`);
});

console.log('\n📁 Project Structure:');
console.log('xml-convert/');
console.log('├── package.json          # Dependencies and scripts');
console.log('├── converter.js          # Main conversion logic');
console.log('├── cli.js                # Command-line interface');
console.log('├── index.js              # Example usage');
console.log('├── README.md             # Documentation');
console.log('├── .gitignore            # Git ignore rules');
console.log('└── export/               # Output directory');
console.log('    └── .gitkeep          # Keep folder in git');

console.log('\n🔧 To get started:');
console.log('1. npm install            # Install dependencies');
console.log('2. npm run convert <file> # Convert XML file');
console.log('3. node cli.js stats <file> # Show file stats');

console.log('\n📖 Example usage:');
console.log('npm run convert ReportOptimizer-shorter.xml');
console.log('npm run convert ReportOptimizer-shorter.xml -f json');
console.log('npm run convert ReportOptimizer-shorter.xml -o my-report -s');

// Check XML files in directory
try {
    const xmlFiles = fs.readdirSync('.').filter(f => f.endsWith('.xml'));
    if (xmlFiles.length > 0) {
        console.log('\n📄 XML files found:');
        xmlFiles.forEach(file => {
            const stats = fs.statSync(file);
            const size = (stats.size / 1024).toFixed(2);
            console.log(`   ${file} (${size} KB)`);
        });
    }
} catch (error) {
    console.log('\n📄 No XML files found in current directory');
}

console.log('\n✨ Project setup complete! Install dependencies to start converting.');
