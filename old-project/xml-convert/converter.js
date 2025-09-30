const fs = require('fs-extra');
const xml2js = require('xml2js');
const createCsvWriter = require('csv-writer').createObjectCsvWriter;
const path = require('path');

class MT5XMLConverter {
    constructor() {
        this.parser = new xml2js.Parser({
            explicitArray: false,
            ignoreAttrs: false,
            mergeAttrs: true
        });
        this.exportDir = path.join(__dirname, 'export');
    }

    /**
     * Ensure export directory exists
     */
    async ensureExportDir() {
        await fs.ensureDir(this.exportDir);
    }

    /**
     * Parse XML file to JavaScript object
     * @param {string} xmlFilePath - Path to XML file
     * @returns {Object} Parsed XML data
     */
    async parseXML(xmlFilePath) {
        try {
            const xmlData = await fs.readFile(xmlFilePath, 'utf8');
            const result = await this.parser.parseStringPromise(xmlData);
            return result;
        } catch (error) {
            throw new Error(`Failed to parse XML: ${error.message}`);
        }
    }

    /**
     * Extract MT5 optimization results from parsed XML
     * @param {Object} parsedXML - Parsed XML object
     * @returns {Object} Structured data with metadata and results
     */
    extractMT5Data(parsedXML) {
        const workbook = parsedXML.Workbook;
        
        // Extract document properties (metadata)
        const docProps = workbook.DocumentProperties || {};
        const metadata = {
            title: docProps.Title || '',
            author: docProps.Author || '',
            created: docProps.Created || '',
            company: docProps.Company || '',
            version: docProps.Version || '',
            server: docProps.Server || '',
            deposit: docProps.Deposit || '',
            leverage: docProps.Leverage || '',
            condition: docProps.Condition || ''
        };

        // Extract worksheet data
        const worksheet = workbook.Worksheet;
        const table = worksheet.Table;
        const rows = Array.isArray(table.Row) ? table.Row : [table.Row];

        // First row contains headers
        const headerRow = rows[0];
        const headers = [];
        
        if (headerRow && headerRow.Cell) {
            const headerCells = Array.isArray(headerRow.Cell) ? headerRow.Cell : [headerRow.Cell];
            headerCells.forEach(cell => {
                if (cell.Data && cell.Data._) {
                    headers.push(cell.Data._);
                } else if (cell.Data) {
                    headers.push(cell.Data);
                }
            });
        }

        // Extract data rows
        const dataRows = [];
        for (let i = 1; i < rows.length; i++) {
            const row = rows[i];
            if (row && row.Cell) {
                const cells = Array.isArray(row.Cell) ? row.Cell : [row.Cell];
                const rowData = {};
                
                cells.forEach((cell, index) => {
                    const header = headers[index] || `Column${index + 1}`;
                    let value = '';
                    
                    if (cell.Data) {
                        if (cell.Data._) {
                            value = cell.Data._;
                        } else {
                            value = cell.Data;
                        }
                        
                        // Convert numeric strings to numbers
                        if (typeof value === 'string' && !isNaN(value) && value !== '') {
                            value = parseFloat(value);
                        }
                        
                        // Convert boolean strings
                        if (value === 'true') value = true;
                        if (value === 'false') value = false;
                    }
                    
                    rowData[header] = value;
                });
                
                dataRows.push(rowData);
            }
        }

        return {
            metadata,
            headers,
            data: dataRows,
            totalRecords: dataRows.length
        };
    }

    /**
     * Convert XML to JSON format
     * @param {string} xmlFilePath - Path to XML file
     * @param {string} outputFileName - Output file name (without extension)
     * @returns {string} Path to generated JSON file
     */
    async convertToJSON(xmlFilePath, outputFileName) {
        await this.ensureExportDir();
        
        const parsedXML = await this.parseXML(xmlFilePath);
        const structuredData = this.extractMT5Data(parsedXML);
        
        const jsonFilePath = path.join(this.exportDir, `${outputFileName}.json`);
        await fs.writeFile(jsonFilePath, JSON.stringify(structuredData, null, 2), 'utf8');
        
        console.log(`✅ JSON file created: ${jsonFilePath}`);
        return jsonFilePath;
    }

    /**
     * Convert XML to CSV format
     * @param {string} xmlFilePath - Path to XML file
     * @param {string} outputFileName - Output file name (without extension)
     * @returns {string} Path to generated CSV file
     */
    async convertToCSV(xmlFilePath, outputFileName) {
        await this.ensureExportDir();
        
        const parsedXML = await this.parseXML(xmlFilePath);
        const structuredData = this.extractMT5Data(parsedXML);
        
        if (structuredData.data.length === 0) {
            throw new Error('No data found to convert to CSV');
        }

        // Create CSV writer with dynamic headers
        const csvFilePath = path.join(this.exportDir, `${outputFileName}.csv`);
        const csvWriter = createCsvWriter({
            path: csvFilePath,
            header: structuredData.headers.map(header => ({
                id: header,
                title: header
            }))
        });

        await csvWriter.writeRecords(structuredData.data);
        
        // Also create a metadata CSV file
        const metadataFilePath = path.join(this.exportDir, `${outputFileName}_metadata.csv`);
        const metadataWriter = createCsvWriter({
            path: metadataFilePath,
            header: [
                { id: 'property', title: 'Property' },
                { id: 'value', title: 'Value' }
            ]
        });

        const metadataRecords = Object.entries(structuredData.metadata).map(([key, value]) => ({
            property: key,
            value: value
        }));

        await metadataWriter.writeRecords(metadataRecords);
        
        console.log(`✅ CSV files created:`);
        console.log(`   Data: ${csvFilePath}`);
        console.log(`   Metadata: ${metadataFilePath}`);
        
        return { dataFile: csvFilePath, metadataFile: metadataFilePath };
    }

    /**
     * Convert XML to both JSON and CSV formats
     * @param {string} xmlFilePath - Path to XML file
     * @param {string} outputFileName - Output file name (without extension)
     * @returns {Object} Paths to generated files
     */
    async convertToBoth(xmlFilePath, outputFileName) {
        const jsonPath = await this.convertToJSON(xmlFilePath, outputFileName);
        const csvPaths = await this.convertToCSV(xmlFilePath, outputFileName);
        
        return {
            json: jsonPath,
            csv: csvPaths
        };
    }

    /**
     * Get conversion statistics
     * @param {string} xmlFilePath - Path to XML file
     * @returns {Object} Statistics about the XML file
     */
    async getStats(xmlFilePath) {
        const parsedXML = await this.parseXML(xmlFilePath);
        const structuredData = this.extractMT5Data(parsedXML);
        
        return {
            fileName: path.basename(xmlFilePath),
            fileSize: (await fs.stat(xmlFilePath)).size,
            totalRecords: structuredData.totalRecords,
            columns: structuredData.headers.length,
            metadata: structuredData.metadata
        };
    }
}

module.exports = MT5XMLConverter;
