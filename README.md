# NOSC
NOSC - Network Operations Sustainment Center

NOSC provides an integrated interface for network management utilities.

-- FEATURES
  - Network device list management between multiple users.

  - Graphical interface for sorting and grouping devices, and for launching
    remote management and network utilities: PuTTY, pSCP, Ping, Traceroute,
    HTTP, HTTPS, Microsoft Terminal Services Client (MSTSC).

  - Defense Information Systems Agency (DISA) Security Technical Implementation
    Guide (STIG) checklist automation and graphical interface.

-- CHANGE LOG

    4/11/2018 [DKI] >> Updated Device/SingleView and SortedTreeView
    * Fixed pscp Send-File function call in SingleView context menu
    + Expanded the notes for the SortedTreeView
    ~ Refactored the definition processing to perform sanity checks, ensuring
      that the definition objects are not null.

    4/10/2018 [DKI] >> pscp Secure Copy Support.
    + Added Device module context menus.
    + Added support functions to Putty module.
    + Expanded SortedTreeView module documentation.

    4/10/2018 [DKI] >> Hotfix patch for PuTTY SSH.
    ~ Moved this log out of the nosc.ps1 file.
    + Added SortedTreeView support for callers of the module to add custom note
      properties to the returned TreeView control.
    + Added hotkey [F1] support for opening SSH to a device.
    + Added sanity checks to ensure a device supports SSH before attempting to
      open an SSH session.
    ~ Updated name of the Open-Putty function to Open-SSH.

    12/30/2017 >> Feature updates and directory structure refactoring.
    + Added ping and traceroute options to the menu options of the device
      single view treeview.
    ~ Renamed the lib folder for the modules to modules.
    ~ Renamed the res folder for images to resources.
    ~ Renamed the doc folder to documentation.
    * Fixed bug with the report viewer introduced by the refactor of the STIG
      viewer.
    + Added summarization of the total number of devices for the report in the
      STIG viewer.
    + Added a utility for parsing cache content from the STIG scanner.  The
      utility is kept in the bin folder.
    + Added to the diff.exe utility to the bin folder.
    + Added database folder for holding information localy.
    + Added settings features and configuration dialog for device module.

    5/23/2017 >> Feature updates and major refactoring.
    + Added STIG Viewer support for viewing STIG rule details and recommended
      validation/fix actions.
    + Added PuTTY support.
    + Added support for marking open findings as having a POA&M in-place.
    + Added images to represent the different compliance states for the the
      tree view navigation pane.
    + Added pop-out functionality for the tree view navigation pane for users
      who need more screen area.
    ~ Refactored the seperate pages/tabs into modules that are loaded dynamically
      by the execution script for easier code maintenance.
    ~ Refactored the navigation TreeView on the Compliance tab into a seperate
      [Custom] class module to enable code reuse for future tabs.

    4/28/2017 >> Feature Updates
    + Added report feature to summarize compliance data.
    - Disabled loading the treeview on opening a compliance report. Users must
      first set their view settings.

    4/27/2017 >> Feature updates.
    - Commented out the SortBy code as it is not fully implemented, and it will
      take a while before it is.  There are much bigger fish to fry first.

    4/26/2017 >> Featrue completion.
    + Finished the tree view grouping settings application logic. The settings
      can now be applied to the tree view as long as data has been loaded.
