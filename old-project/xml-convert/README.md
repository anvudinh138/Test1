# MT5 XML Converter

A Node.js tool to convert MetaTrader 5 (MT5) XML optimization reports to JSON and CSV formats.

## Features

- ✅ Convert MT5 XML reports to JSON format
- ✅ Convert MT5 XML reports to CSV format (data + metadata)
- ✅ Command-line interface (CLI) for easy usage
- ✅ Automatic export folder management
- ✅ File statistics and metadata extraction
- ✅ Support for large XML files
- ✅ Structured data extraction with proper type conversion

## Installation

1. Clone or download this project
2. Install dependencies:

```bash
npm install
```

## Usage

### Command Line Interface (CLI)

#### Convert XML to JSON and CSV (default)
```bash
npm run convert ReportOptimizer-shorter.xml
```

#### Convert with custom output name
```bash
npm run convert ReportOptimizer-shorter.xml -- -o my-report
```

#### Convert to specific format only
```bash
# JSON only
npm run convert ReportOptimizer-shorter.xml -- -f json

# CSV only
npm run convert ReportOptimizer-shorter.xml -- -f csv
```

#### Show file statistics during conversion
```bash
npm run convert ReportOptimizer-shorter.xml -- -s
```

#### View file statistics only
```bash
npm run stats ReportOptimizer-shorter.xml
```

#### List XML files in current directory
```bash
npm run list
```

### Programmatic Usage

```javascript
const MT5XMLConverter = require('./converter');

async function convertFile() {
    const converter = new MT5XMLConverter();
    
    try {
        // Convert to both JSON and CSV
        const results = await converter.convertToBoth(
            'ReportOptimizer-shorter.xml', 
            'my-output'
        );
        
        console.log('JSON file:', results.json);
        console.log('CSV files:', results.csv);
        
        // Get file statistics
        const stats = await converter.getStats('ReportOptimizer-shorter.xml');
        console.log('Total records:', stats.totalRecords);
        
    } catch (error) {
        console.error('Error:', error.message);
    }
}

convertFile();
```

## Output Structure

### JSON Format
The JSON output contains:
- `metadata`: Document properties (title, author, server, etc.)
- `headers`: Column names from the XML table
- `data`: Array of optimization results with proper data types
- `totalRecords`: Number of records processed

Example JSON structure:
```json
{
  "metadata": {
    "title": "ye_1 EURUSD,M1 2025.06.10-2025.09.10",
    "author": "MetaQuotes Ltd.",
    "server": "Exness-MT5Trial17",
    "deposit": "10000 USD",
    "leverage": "500"
  },
  "headers": ["Pass", "Result", "Profit", "Expected Payoff", ...],
  "data": [
    {
      "Pass": 612,
      "Result": 10006.99,
      "Profit": 6.99,
      "Expected Payoff": 2.33,
      "InpEntryMethod": 0,
      "InpTrendTimeframe": 30
    }
  ],
  "totalRecords": 42
}
```

### CSV Format
Two CSV files are generated:
1. `{filename}.csv`: Main data with all optimization results
2. `{filename}_metadata.csv`: Document metadata as key-value pairs

## File Structure

```
xml-convert/
├── converter.js          # Main conversion logic
├── cli.js                # Command-line interface
├── index.js              # Example usage and main entry
├── package.json          # Project configuration
├── export/               # Output directory
│   └── .gitkeep         # Keeps export folder in git
└── README.md            # This documentation
```

## Supported XML Structure

This converter is designed for MT5 optimization report XML files with the following structure:
- Microsoft Excel XML format
- Document properties section
- Worksheet with table data
- First row as headers
- Subsequent rows as data records

## Data Type Conversion

The converter automatically handles:
- ✅ Numeric strings → Numbers
- ✅ "true"/"false" strings → Booleans  
- ✅ Empty cells → Empty strings
- ✅ Preserves original strings when appropriate

## Error Handling

- File existence validation
- XML parsing error handling
- Empty data detection
- Graceful error messages with exit codes

## Examples

### Basic Conversion
```bash
# Convert the sample file
npm run convert ReportOptimizer-shorter.xml

# Output:
# ✅ JSON file created: /path/to/export/ReportOptimizer-shorter.json
# ✅ CSV files created:
#    Data: /path/to/export/ReportOptimizer-shorter.csv
#    Metadata: /path/to/export/ReportOptimizer-shorter_metadata.csv
```

### With Statistics
```bash
npm run convert ReportOptimizer-shorter.xml -- -s

# Output:
# 📊 File Statistics:
#    File: ReportOptimizer-shorter.xml
#    Size: 68.00 KB
#    Records: 42
#    Columns: 22
#    Title: ye_1 EURUSD,M1 2025.06.10-2025.09.10
#    Server: Exness-MT5Trial17
#    Created: 2025-09-23T9:01:44Z
```

## Requirements

- Node.js 14+ 
- Dependencies: xml2js, csv-writer, fs-extra, commander

## License

ISC License

## Contributing

Feel free to submit issues and enhancement requests!
