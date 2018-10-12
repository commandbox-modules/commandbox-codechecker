/**
* Start a code review against your code
* .
* {code:bash}
* codechecker run
* {code}
*/
component {
	property name='codeCheckerService' 	inject='codeCheckerService@codechecker-core';
	property name='rulesService' 		inject='rulesService@codechecker-core';
	property name='ExportService' 		inject='ExportService@codechecker-core';
	property name='progress'	 		inject='progressBarGeneric';
	
	/**
	*
	*/
	function run(
		struct categories={ '_all'  : '' },
		string paths='**.cf?',
		numeric minSeverity=1,
		string excelReportPath,
		boolean verbose=false
		) {
		
		// Incoming pattern can be comma delimited list
		paths = paths.listToArray();
		
		job.start( 'Running CodeChecker' );
					
			job.start( 'Resolving files for scan' );
				
				var combinedPaths = [];
				paths.each( function( path ) {
					
					var thisCount = 0;
					job.addLog( 'Collecting files at #path#' );
					
					path = filesystemUtil.resolvePath( path );
					// Fix /model to be /models/** which is probably what they meant
					if( directoryExists( path ) ) {
						path &= '**';
					}
					globber( path )
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
			
			
			if( categories.keyList() == '_all' ) {
				categories = rulesService.getCategories().toList();
			}
	
			codeCheckerService.setCategories( categories );
			codeCheckerService.setMinSeverity( minSeverity );
				
			job.start( 'Running Rules', 10 );
			
				progress.update( 0 );
		
				var currFile = 0;
				combinedPaths.each( function( path ) {
					currFile++;
					job.addLog( 'Scanning ' & path );
					//job.addLog( 'Scanning ' & shortenPath( path ) );
					progress.update( ( currFile/fileCount) * 100, currFile, fileCount );
					if( fileExists( path ) ) {
						var resultsCodeChecker = codeCheckerService.startCodeReview( filepath=path );	
					}
				} );
		
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
			
		if( results.len() ) {	
			print.boldRedLine( ' in #qryCats.recordCount# categor#iif( qryCats.recordCount == 1, de( 'y' ), de( 'ies' ) )#.' );
		} else {
			print.boldRedLine( '.' );			
		}
		
		print.line( '   ----------------------------------------------------------' );
		
		qryCats.each( function( cat ) {
			print.text( '   -- #cat.catCount# issues in ' ).boldBlueLine( cat.category );
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
		
		if( verbose ) {
			results.each( function( result ) {
				print
					.line( '#result.rule# | #result.category# | Severity: #result.severity#', color( result.severity ) )
					.IndentedYellowLine( result.message )
					.IndentedLine( shortenPath( result.directory & result.file & ':' & result.lineNumber ) )
					.line();
			} );
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
	
}

