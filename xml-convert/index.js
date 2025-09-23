const MT5XMLConverter = require('./converter');
const path = require('path');

// Example usage of the converter
async function example() {
    const converter = new MT5XMLConverter();
    
    try {
        console.log('🚀 MT5 XML Converter Example');
        console.log('═'.repeat(40));
        
        // Example with the shorter XML file
        const xmlFile = path.join(__dirname, 'ReportOptimizer-shorter.xml');
        const outputName = 'mt5-report-example';
        
        console.log(`📄 Processing: ${path.basename(xmlFile)}`);
        
        // Show file statistics
        const stats = await converter.getStats(xmlFile);
        console.log('\n📊 File Statistics:');
        console.log(`   Records: ${stats.totalRecords}`);
        console.log(`   Columns: ${stats.columns}`);
        console.log(`   Title: ${stats.metadata.title}`);
        
        // Convert to both JSON and CSV
        console.log('\n🔄 Converting to JSON and CSV...');
        const results = await converter.convertToBoth(xmlFile, outputName);
        
        console.log('\n✨ Conversion completed!');
        console.log(`📁 Files created in: ${path.join(__dirname, 'export')}`);
        
    } catch (error) {
        console.error(`❌ Error: ${error.message}`);
    }
}

// Export the converter class for use in other modules
module.exports = MT5XMLConverter;

// Run example if this file is executed directly
if (require.main === module) {
    example();
}
