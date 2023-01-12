/* ************************************************************************
   Copyright: 2022 Lukas Derendinger
   License:   ???
   Authors:   Lukas Derendinger <lukas@>
 *********************************************************************** */

/**
 * Main application class.
 * @asset(log_trawly/*)
 *
 */
qx.Class.define("log_trawly.Application", {
    extend : callbackery.Application,
    members : {
        main : function() {
            // Call super class
            this.base(arguments);
        }
    }
});
