/**
* Show all rule categories that are registered
* .
* {code:bash}
* codechecker categories
* {code}
*/
component {
	
	/**
	*
	*/
	function run() {
		var codeCheckerService = getInstance( 'codeCheckerService@codechecker-core' ).configure( getCWD() );
		var rules = codeCheckerService.getRulesService().getRulesByCategory();
		
		rules.each( function( category, categoryRules ) {
			print
				.line()
				.boldBlueline( category );
				
			categoryRules.each( function( rule ) {
				print.indentedGreenText( rule.name )
					.greyLine( ' (' & rule.message & ')' );
			} );
		} );
	}
	
}

