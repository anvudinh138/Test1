#!/usr/bin/env node

const { Command } = require('commander');
const path = require('path');
const fs = require('fs-extra');
const MT5XMLConverter = require('./converter');

const program = new Command();
const converter = new MT5XMLConverter();

program
    .name('mt5-xml-converter')
    .description('Convert MT5 XML reports to JSON and CSV formats')
    .version('1.0.0');

program
    .command('convert <input>')
    .description('Convert XML file to JSON and/or CSV')
    .option('-o, --output <name>', 'Output file name (without extension)')
    .option('-f, --format <type>', 'Output format: json, csv, or both', 'both')
    .option('-s, --stats', 'Show file statistics')
    .action(async (input, options) => {
        try {
            // Check if input file exists
            if (!await fs.pathExists(input)) {
                console.error(`❌ Error: Input file '${input}' does not exist`);
                process.exit(1);
            }

            // Generate output filename if not provided
            const outputName = options.output || path.parse(input).name;
            
            console.log(`🔄 Converting ${input}...`);
            console.log(`📁 Output directory: ${path.join(__dirname, 'export')}`);
            
            // Show stats if requested
            if (options.stats) {
                const stats = await converter.getStats(input);
                console.log('\n📊 File Statistics:');
                console.log(`   File: ${stats.fileName}`);
                console.log(`   Size: ${(stats.fileSize / 1024).toFixed(2)} KB`);
                console.log(`   Records: ${stats.totalRecords}`);
                console.log(`   Columns: ${stats.columns}`);
                console.log(`   Title: ${stats.metadata.title}`);
                console.log(`   Server: ${stats.metadata.server}`);
                console.log(`   Created: ${stats.metadata.created}`);
                console.log('');
            }

            // Convert based on format option
            switch (options.format.toLowerCase()) {
                case 'json':
                    await converter.convertToJSON(input, outputName);
                    break;
                case 'csv':
                    await converter.convertToCSV(input, outputName);
                    break;
                case 'both':
                default:
                    await converter.convertToBoth(input, outputName);
                    break;
            }

            console.log('✨ Conversion completed successfully!');
            
        } catch (error) {
            console.error(`❌ Error: ${error.message}`);
            process.exit(1);
        }
    });

program
    .command('stats <input>')
    .description('Show statistics about XML file')
    .action(async (input) => {
        try {
            if (!await fs.pathExists(input)) {
                console.error(`❌ Error: Input file '${input}' does not exist`);
                process.exit(1);
            }

            const stats = await converter.getStats(input);
            
            console.log('\n📊 MT5 XML File Statistics');
            console.log('═'.repeat(40));
            console.log(`File Name: ${stats.fileName}`);
            console.log(`File Size: ${(stats.fileSize / 1024).toFixed(2)} KB`);
            console.log(`Total Records: ${stats.totalRecords}`);
            console.log(`Columns: ${stats.columns}`);
            console.log('');
            console.log('📋 Metadata:');
            console.log('─'.repeat(20));
            Object.entries(stats.metadata).forEach(([key, value]) => {
                if (value) {
                    console.log(`${key.charAt(0).toUpperCase() + key.slice(1)}: ${value}`);
                }
            });
            console.log('');
            
        } catch (error) {
            console.error(`❌ Error: ${error.message}`);
            process.exit(1);
        }
    });

program
    .command('list')
    .description('List XML files in current directory')
    .action(async () => {
        try {
            const files = await fs.readdir('.');
            const xmlFiles = files.filter(file => path.extname(file).toLowerCase() === '.xml');
            
            if (xmlFiles.length === 0) {
                console.log('📁 No XML files found in current directory');
                return;
            }

            console.log('\n📄 XML Files Found:');
            console.log('═'.repeat(30));
            
            for (const file of xmlFiles) {
                const stats = await fs.stat(file);
                const size = (stats.size / 1024).toFixed(2);
                console.log(`${file} (${size} KB)`);
            }
            console.log('');
            
        } catch (error) {
            console.error(`❌ Error: ${error.message}`);
            process.exit(1);
        }
    });

// Show help if no command provided
if (process.argv.length <= 2) {
    program.help();
}

program.parse();
