/**
* Start a code review against your code
* .
* {code:bash}
* codechecker run
* {code}
* .
* If a .codechecker.json file is found in the current working directory, it will be picked up and used.
* This file can contain the following keys:
* .
* - paths - Comma delimited list of file globbing paths to scan if nothing is passed to this command
* - excludePaths - Comma delimited list of file globbing paths to ignore
* - minSeverity - Minimum rule severity to consider if nothing is passed to this command
* - includeRules - A struct of arrays where each struct key is a rule category and the array contains rule names to run.
* - excludeRules - Same format as includeRules but these rules are EXCLUDED from the final list.
* - ruleFiles - Array of absolute or relative (to the JSON file) paths to JSON files containing an arary of structs defining rules to run
* - customRules - An array of structs defining rules to run.
* .
* An example rule struct would be like so:
* {code:js}
* {
*  "pattern": "cfoutput",
*  "message": "CFoutput is lame",
*  "category": "One-off Rules",
*  "name": "Don't use CFoutput",
*  "extensions": "cfm,cfc",
*  "severity": "3"
* }
* {code}
*/
component {
	property name='ExportService' 		inject='ExportService@codechecker-core';
	property name='progress'	 		inject='progressBarGeneric';
	property name='REPLHighlighter'	 	inject='REPLHighlighter';
	property name='p'					inject='print';

	/**
	* @paths Comma delimited list of file globbing paths to scan. i.e. **.cf?
	* @paths.optionsFileComplete true
	* @excludePaths Comma delimited list of file globbing paths to ignore
	* @excludePaths.optionsFileComplete true
	* @categories Comma delimited list of categories of rules to run
	* @categories.optionsUDF categoryComplete
	* @minSeverity Minimum rule severity to consider. Level 1-5
	* @minSeverity.options 1,2,3,4,5
	* @excelReportPath Path to write Excel report to
	* @configPath File path to a config JSON file, or to a directory containing a .codechecker.json file.
	* @verbose Output full list of files being scanned and all items found to the console
	* @jsonFormatter if not empty will output a CI json
	* @jsonFormatter.options codeclimate
	* @failOnMatch Sets a non-zero exit code if any matches are found
	*/
	function run(
		string paths,
		string excludePaths,
		string categories='',
		numeric minSeverity,
		string excelReportPath,
		string configPath=getCWD(),
		boolean verbose=false,
		string jsonFormatter='',
		boolean failOnMatch=false
		) {

		try {
			// Get a fresh instance since the loaded rules are directory-aware
			if( arguments.configPath.left( 4 ) != 'http' ) {
				arguments.configPath = resolvePath( arguments.configPath );	
			}
			if( !( fileExists( configPath ) || directoryExists( configPath ) ) ) {
				error( 'Config path [#configPath#] does not exist.' );
			}
			var codeCheckerService = getInstance( 'codeCheckerService@codechecker-core' ).configure( arguments.configPath, arguments.categories, arguments.minSeverity ?: '' );
		} catch( codecheckerMissingRuleFile var e ) {
			error( message=e.message, detail=e.detail );
		}

		// Incoming pattern can be comma delimited list

		var configJSON = codeCheckerService.getConfigJSON()
		var thisPaths = arguments.paths ?: configJSON.paths ?: '**.cf?';
		thisPaths = thisPaths.listToArray();
		
		
		// Exclude patterns can be a comma delimited list or an array
		var thisExcludePaths = arguments.excludePaths ?: configJSON.excludePaths ?: '';
		if( !isArray( thisExcludePaths ) ) {
			thisExcludePaths = thisExcludePaths.listToArray();
		}
		thisExcludePaths = thisExcludePaths.map( function( path ) {
			path = filesystemUtil.resolvePath( path );
			if ( directoryExists( path ) ) {
				path &= '**';
			}

			return path;
		} );


		job.start( 'Running CodeChecker' );

			job.start( 'Resolving files for scan' );

				var combinedPaths = [];
				thisPaths.each( function( path ) {

					var thisCount = 0;
					job.addLog( 'Collecting files at #path#' );

					path = filesystemUtil.resolvePath( path );
					// Fix /model to be /models/** which is probably what they meant
					if( directoryExists( path ) ) {
						path &= '**';
					}
					globber( path )
						.setExcludePattern( thisExcludePaths )
						.asArray()
						.matches()
						.each( function( i ) {
							i = fileSystemUtil.normalizeSlashes( i );
							// Only store up unique paths and ignore that pesky .git folder
							if( !combinedPaths.contains( i ) && !i.find( '/.git/' ) ) {
								combinedPaths.append( i );
								thisCount++;
							}
						} );

					job.addLog( '#thisCount# files found' );


				} );

			var fileCount = combinedPaths.len();

			job.complete( verbose );

			var huevos = [ 'Starting Rules Engine', 'Polishing ASCII Art', 'Sorting JSON', 'Aligning Goals', 'Brewing Coffee', 'Assessing penalty kicks', 'Washing vegetables', 'Bolstering Public Opinion', 'Adjusting Volume', 'Replacing Batteries', 'Loreming Ipsums', 'Reducing Technical Debt' ];
			job.start( huevos[ randRange( 1, huevos.len() ) ] );
				sleep( 2000 );
			job.complete( verbose );


			job.start( 'Running Rules', 10 );

				progress.update( 0 );

				var currFile = 0;
				var hasErroredScan = false;
				combinedPaths.each( function( path ) {
					currFile++;
					// Interactive jobs are not thread safe!!
					lock name="codechecker-run-update" timeout="20" {
						job.addLog( 'Scanning ' & shortenPath( path ) );
						progress.update( ( currFile/fileCount) * 100, currFile, fileCount );
					}
					if( fileExists( path ) ) {
						try {
							var resultsCodeChecker = codeCheckerService.startCodeReview( filepath=path );
						} catch( any var e ) {
							hasErroredScan = true;
							job.addErrorLog( 'Error scanning ' & shortenPath( path ) );
							job.addErrorLog( e.message );
							job.addErrorLog( e.detail ?: '' );
							if( e.tagContext.len() ) {
								job.addErrorLog( e.tagContext[ 1 ].template & ':' &  e.tagContext[ 1 ].line );
							}
						}
					}
				},
				// Parallel execution
				true,
				// No more threads than CPU cores.
				createObject( 'java', 'java.lang.Runtime' ).getRuntime().availableProcessors() );

				progress.clear();

			job.complete( verbose );

			var results = codeCheckerService.getResults();

		job.complete( verbose );

		var qryResult = queryNew( 'directory,file,rule,message,linenumber,category,severity' );

		results.each( function( result ) {
			qryResult.addRow( result );
		} );

		var qryCats = queryExecute(
			'SELECT category, count(1) as catCount
			FROM qryResult
			GROUP BY category',
			[],
			{ dbtype='query' }
		 );

		var colors = [ 'DarkMagenta2', 'DeepPink2', 'Blue1', 'SpringGreen2', 'OrangeRed1', 'Grey' ];
		var thisColor = colors[ randRange( 1, colors.len() ) ];

		print
			.line()
			.boldLine( '   ____ ____ ___  ____ ____ _  _ ____ ____ _  _ ____ ____  ', 'on#thisColor#' )
			.boldLine( '   |    |  | |  \ |___ |    |__| |___ |    |_/  |___ |__/  ', 'on#thisColor#' )
			.boldLine( '   |___ |__| |__/ |___ |___ |  | |___ |___ | \_ |___ |  \  ', 'on#thisColor#' )
			.boldLine( '                                                           ', 'on#thisColor#' )
			.line()
			.boldRedText( '   #qryResult.recordcount# issues found' );

		var numCats = codeCheckerService.getRules().reduce( (categories,r)=>{
				categories[ r.category ] = '';
				return categories;
			}, {} )
			.keyArray()
			.len();
		print.boldRedText( ' in #numCats# categor#iif( numCats == 1, de( 'y' ), de( 'ies' ) )#' );

		var numRules = codeCheckerService.getRules().len();
		print.boldRedLine( ' using #numRules# rule#iif( numRules == 1, de( '' ), de( 's' ) )#.' );

		print.line( '   ----------------------------------------------------------' );

		qryCats.each( function( cat ) {
			print.text( '   -- #cat.catCount# issue#iif( cat.catCount == 1, de( '' ), de( 's' ) )# in ' ).boldBlueLine( cat.category );
		} );

		if( results.len() ) {
			print
				.line( '   ----------------------------------------------------------' )
				.line()
				.yellow( '   Export the full results to Excel with the "' ).white( 'excelReportPath' ).yellowLine( '" parameter.' )
				.yellow( '   See full results with "' ).white( '--verbose | more' ).yellowLine( '".' )
				.yellow( '   Filter out lower severity issues with "' ).white( 'minSeverity=5' ).yellowLine( '"' )
				.line()
				.line();
		}

		if( !isNull( arguments.excelReportPath ) ) {
			excelReportPath = filesystemUtil.resolvePath( excelReportPath );

			// If we were given a directory
			if( !( excelReportPath.right( 4 ) == '.xls' ) ){
				// Make up a file name
				excelReportPath &= '/codechecker-report-#dateTimeFormat( now(), 'yyyy-mm-dd-HHMMSS' )#.xls';
			}

			var binary = exportService.generateExcelReport( results, categories );

			directoryCreate( getDirectoryFromPath( excelReportPath ), true, true );
			fileWrite( excelReportPath, binary );

			print
				.greenLine( '   Excel report created at:' )
				.greenLine( '      #excelReportPath#' )
				.line()
				.line();

		}

		if( hasErroredScan && !verbose ) {
			print
				.line()
				.boldRedLine( '   At least one file caused an error while being scanned.' )
				.boldRedLine( '   Run this command with "--verbose" for details and please report it as a bug.' )
				.line()
				.line();
		}

		if( verbose ) {
			results.each( function( result ) {
				print
					.line( '#result.rule# | #result.category# | Severity: #result.severity#', color( result.severity ) )
					.IndentedYellowLine( result.message )
					.IndentedLine( shortenPath( result.directory & result.file & ':' & result.lineNumber ) );

				var codeLine = trim( result.codeLine ?: '' );
				if( codeLine.len() ) {
					if( codeLine contains "<cf" ) {
						var formattedCodeLine = tagHighlighter( codeLine );
					} else {
						var formattedCodeLine = REPLHighlighter.highlight( '', codeLine ).toAnsi( shell.getReader().getTerminal() );
					}
					print
						.line()
						.IndentedLine( formattedCodeLine );
				}

				print.line();
			} );
		}

		if (jsonFormatter.len()) {
			var result_json = [];
			switch (jsonFormatter) {
				case 'codeclimate':
					var severityLabel=['info', 'minor', 'major', 'critical', 'blocker'];
					result_json = results.map(function(result) {
						return {
							'type': 'issue',
							'description': result.message,
							'check_name': result.rule,
							'severity': severityLabel[result.severity],
							'categories': [
								result.category, // FIXME: Use lookup map to use supported names
							],
							'location': {
								'path': replace(result.directory & result.file, filesystemUtil.resolvePath(''), ''),
								'lines': {
									'begin': result.lineNumber
								} 
							}
						};
					} );
					break;
			}
			fileWrite(filesystemUtil.resolvePath("codechecker.json"), serializeJSON(result_json));
		}

		if( results.len() && failOnMatch ) {
			setExitCode( 1 );
		}
	}

	/**
	* Keep file paths from wrapping.  That's just ugly.
	*/
	private function shortenPath( path ) {
		var maxWidth = shell.getTermWidth() - 25;
		var displayPath = path;
		// Deal with possibly very deep folder structures which would look bad in the menu or possible reach off the screen
		if( displayPath.len() > maxWidth && displayPath.listLen( '/' ) > 2 ) {
			var pathLength = displayPath.listLen( '/' );
			var firstFolder = displayPath.listFirst( '/' );
			var lastFolder = displayPath.listLast( '/' );
			var middleStuff = displayPath.listDeleteAt( pathLength, '/' ).listDeleteAt( 1, '/' );
			// Ignoring slashes here.  Doesn't need to be exact.
			var leftOverLen = max( maxWidth - (firstFolder.len() + lastFolder.len() ), 1 );
			// This will shorten the path to C:/firstfolder/somes/tuff.../lastFolder/
			// with a final result that is close to 50 characters
			displayPath = firstFolder & '/' & middleStuff.left( leftOverLen ) & '.../' & lastFolder;
		}
		return displayPath;
	}


	/**
	* Translate severity number of 1-5 into a color.  More red means more bad.  More yellow means more meh.
	*/
	private function color( severity ) {

		if( severity == 1 ) {
			return 'Gold1';
		} else if( severity == 2 ) {
			return 'Orange1';
		} else if( severity == 3 ) {
			return 'DarkOrange1';
		} else if( severity == 4 ) {
			return 'OrangeRed1';
		} else {
			return 'Red1';
		}

	}

	function categoryComplete() {
		try {
			// Get a fresh instance since the loaded rules are directory-aware
			var codeCheckerService = getInstance( 'codeCheckerService@codechecker-core' ).configure( getCWD() );
			return codeCheckerService.getRulesService().getCategories();
		} catch( any var e ) {}
		return [];
	}

	// basic tag hightlighting
	private function tagHighlighter( codeLine ) {


		// highight quoted strings
		codeLine = reReplaceNoCase( codeLine, '("[^"<##]*")', p.red( '\1' ), 'all' );
		codeLine = reReplaceNoCase( codeLine, "('[^'<##]*')", p.red( '\1' ), 'all' );


		// highlight tag names
		codeLine = reReplaceNoCase( codeLine, '<([^ >]*)( |>)', '<' & p.boldAqua( '\1' ) & '\2', 'all' );

		// Highlight function calls
		codeLine = reReplaceNoCase( codeLine, '(^|[ \-##\.\{\}\(\)])([^ \-##\.\{\}\(\)]*)(\()', '\1' & p.boldYellow( '\2' ) & '\3', 'all' );

		var reservedWords = [
			' var ',
			' true ',
			' false ',
			' function',
			' GT ',
			' LT ',
			' GTE ',
			' LTE ',
			' EQ ',
			' NEQ ',
			' IS ',
			' AND ',
			' OR '
		].toList( '|' );

		// highight reserved words
		codeLine = reReplaceNoCase( codeLine, '(#reservedWords#)', p.boldCyan( '\1' ), 'all' );

		// highight pound signs
		codeLine = reReplaceNoCase( codeLine, '##', p.boldCyan( '##' ), 'all' );


		return codeLine;
	}

}

