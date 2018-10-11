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
		Globber paths
		) {
		
		if( isNull( arguments.paths ) ) {
			arguments.paths = globber( getCWD() & '**.cf?' );
		}
		
		job.start( 'Running CodeChecker' );
					
			job.start( 'Resolving files for scan' );
				
				// This line actually hits the file system to resolve the globbing pattern (lazy loaded)
				var fileCount = paths.count();
						
			job.complete();
					
			var huevos = [ 'Starting Rules Engine', 'Polishing ASCII Art', 'Sorting JSON', 'Aligning Goals', 'Brewing Coffee', 'Assessing penalty kicks', 'Washing vegetables', 'Bolstering Public Opinion', 'Adjusting Volume', 'Replacing Batteries', 'Loreming Ipsums', 'Reducing Technical Debt' ];
			job.start( huevos[ randRange( 1, huevos.len() ) ] );
				sleep( 2000 );
			job.complete();
			
			
			if( categories.keyList() == '_all' ) {
				categories = rulesService.getCategories().toList();
			}
	
			codeCheckerService.setCategories( categories );
	
			job.start( 'Running Rules', 10 );
			
				progress.update( 0 );
		
				var currFile = 0;
				paths.apply( function( path ) {
					currFile++;
					job.addLog( 'Scanning ' & shortenPath( path ) );
					progress.update( ( currFile/fileCount) * 100, currFile, fileCount );
					if( fileExists( path ) ) {
						var resultsCodeChecker = codeCheckerService.startCodeReview( filepath=path );	
					}
				} );
		
				progress.clear();
				
			job.complete();
	
			var results = codeCheckerService.getResults();

		job.complete();
		
		print.line( results.len() & ' items found.' );
		
		results.each( function( result ) {
			print
				.line( '#result.rule# | #result.category# | Severity: #result.severity#', color( result.severity ) )
				.IndentedLine( shortenPath( result.directory & result.file & ':' & result.lineNumber ) )
				.line();
		} );
	}

	/**
	* Keep file paths from wrapping.  That's just ugly.
	*/
	private function shortenPath( path ) {
		var maxWidth = shell.getTermWidth() - 25;
		var appFileSystemPathDisplay = fileSystemUtil.normalizeSlashes( path );
		// Deal with possibly very deep folder structures which would look bad in the menu or possible reach off the screen
		if( appFileSystemPathDisplay.len() > maxWidth && appFileSystemPathDisplay.listLen( '/' ) > 2 ) {
			var pathLength = appFileSystemPathDisplay.listLen( '/' );
			var firstFolder = appFileSystemPathDisplay.listFirst( '/' );
			var lastFolder = appFileSystemPathDisplay.listLast( '/' );
			var middleStuff = appFileSystemPathDisplay.listDeleteAt( pathLength, '/' ).listDeleteAt( 1, '/' );
			// Ignoring slashes here.  Doesn't need to be exact.
			var leftOverLen = max( maxWidth - (firstFolder.len() + lastFolder.len() ), 1 );
			// This will shorten the path to C:/firstfolder/somes/tuff.../lastFolder/
			// with a final result that is close to 50 characters
			appFileSystemPathDisplay = firstFolder & '/' & middleStuff.left( leftOverLen ) & '.../' & lastFolder;
		}
		return appFileSystemPathDisplay;
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

