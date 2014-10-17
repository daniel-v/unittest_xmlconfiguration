Unittest Xml Configuration
=====

This library provides a way for Dart's unittest results to be written to XML files, thus integration with `Jenkins` is a lot easier.

## Changelog

#####v0.1.2
New config parameter:

* `packageName` that will be prepended to className when XML generation is being executed. Jenkins will not put these tests under (root) any more.

#####v0.1.1
Xml generation updated so that
 
* teststuit diplays that classname on which the test are being run
* testcase name does not include classname any more

#####v0.1.0
Initial release

