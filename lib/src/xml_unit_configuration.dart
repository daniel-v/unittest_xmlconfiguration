part of unittest_xmlconfiguration;

class _XmlUnitEnvironmentConfigBuilder {

  void set autoStartTests(bool autoStart) {
    _autoStartTests = autoStart;
  }

  void set outputXmlPath(String path) {
    _outputXmlPath = path;
  }

  void set className(String className) {
    _className = className;
  }

  XmlUnitEnvironmentConfig buildConfiguration() {
    return new XmlUnitEnvironmentConfig._(autoStart: _autoStartTests, outputPath: _outputXmlPath, className: _className);
  }

  bool _autoStartTests = true;
  String _outputXmlPath = './';
  String _className = '';
}

class XmlUnitEnvironmentConfig {

  XmlUnitEnvironmentConfig._({bool autoStart: true, String outputPath: './', String className: ''})
      : _autoStart = autoStart,
        _outputXmlPath = outputPath,
        _className = className;

  static _XmlUnitEnvironmentConfigBuilder builder() {
    return new _XmlUnitEnvironmentConfigBuilder();
  }

  final bool _autoStart;
  final String _outputXmlPath;
  final String _className;
}


class XmlUnitConfiguration extends SimpleConfiguration {

  factory XmlUnitConfiguration.setUnittestConfiguration(XmlUnitEnvironmentConfig xmlUnitConfig) {
    XmlUnitConfiguration config = new XmlUnitConfiguration._()
      .._autoStart = xmlUnitConfig._autoStart
      .._outputPath = xmlUnitConfig._outputXmlPath
      .._className = xmlUnitConfig._className;
    unittestConfiguration = config;
    return config;
  }

  /// Set's [unittestConfiguration] to use XmlUnitConfiguration
  XmlUnitConfiguration._() : super(),
    _testStartTime = new DateTime.now(),
    _hostname = Platform.localHostname {
    _output = new StringBuffer();
    throwOnTestFailures = false;
    stopTestOnExpectFailure = false;
  }

  @override
  String get name => 'XmlUnitConfiguration';

  @override
  void onInit() {
    // override to avoid a call to "_postMessage(String)"
    filterStacks = true;
    _receivePort = new ReceivePort();
    _messagesByTestCase = new Map<TestCase, List<String>>();
  }

  @override
  void onLogMessage(TestCase testCase, String message) {
    _messagesByTestCase.putIfAbsent(testCase, () => new List()).add(message);
  }

  @override
  void onSummary(int passed, int failed, int errors, List<TestCase> results, String uncaughtError) {
    XmlBuilder xmlBuilder = _buildXmlTestSuit(results, failed, errors, uncaughtError);
    String formattedXmlString = xmlBuilder.build().toXmlString(pretty: true);
    _output.write(formattedXmlString);
  }

  XmlBuilder _buildXmlTestSuit(List<TestCase> results, int failed, int errors, String uncaughtError) {
    int totalTime = results
        .map((TestCase testCase) => testCase.runningTime == null ? 0 : testCase.runningTime.inMilliseconds)
        .reduce((int total, int el) => total + el);
    int skipped = results.where((TestCase testCase) => !testCase.enabled).length;

    XmlBuilder xmlBuilder = new XmlBuilder();
    xmlBuilder.processing('xml', 'version="1.0" encoding="UTF-8"');
    xmlBuilder.element("testsuit", attributes: {
      "name" : _className,
      "hostname": this._hostname,
      "tests": results.length.toString(),
      "failures": failed.toString(),
      "errors": errors.toString(),
      "skipped": skipped.toString(),
      "time": (totalTime / 1000).toString(),
      "timestamp": _testStartTime.toString()
    }, nest: () {
      _buildXmlTestCasesResults(xmlBuilder, results);
      _writeErrorIfAny(xmlBuilder, uncaughtError);
    });
    return xmlBuilder;
  }

  void _writeErrorIfAny(XmlBuilder xmlBuilder, String uncaughtError) {
    if(uncaughtError != null) {
      xmlBuilder.element("system-err", nest: () {
        xmlBuilder.text(uncaughtError);
      });
    }
  }

  void _buildXmlTestCasesResults(XmlBuilder xmlBuilder, List<TestCase> results) {
    for (TestCase testCase in results) {
      _buildXmlTestCaseResult(testCase, xmlBuilder);
    }
  }

  void _buildXmlTestCaseResult(TestCase testCase, XmlBuilder xmlBuilder) {
    int time = testCase.runningTime != null ? testCase.runningTime.inMilliseconds : 0;
    String testCaseDescription = testCase.description;
    String descriptionWithoutClassname = testCaseDescription.startsWith(_className)
        ? testCaseDescription.replaceFirst(_className,  "").trim()
        : testCaseDescription;
    xmlBuilder.element("testcase", attributes: {
      "id": testCase.id.toString(),
      "classname": _className,
      "name": descriptionWithoutClassname,
      "time": (time / 1000.0).toString()
    }, nest: () {
      _buildXmlTestResult(testCase, xmlBuilder);
      _buildXmlTestSystemOut(testCase, xmlBuilder);
      _buildXmlTestStackTrace(testCase, xmlBuilder);
    });
  }

  void _buildXmlTestResult(TestCase testCase, XmlBuilder xmlBuilder) {
    if (testCase.result == FAIL) {
      xmlBuilder.element("failure", nest: () {
        xmlBuilder.text(testCase.message);
      });
    } else if (testCase.result == ERROR) {
      xmlBuilder.element("error", nest: () {
        xmlBuilder.text(testCase.message);
      });
    } else if (!testCase.enabled) {
      xmlBuilder.element("skipped", nest: () {
        xmlBuilder.text(testCase.message);
      });
    }
  }

  void _buildXmlTestStackTrace(TestCase testCase, XmlBuilder xmlBuilder) {
    if(testCase.stackTrace != null) {
      xmlBuilder.element("system-out", nest: () {
        xmlBuilder.text(testCase.stackTrace.toString());
      });
    }
  }

  void _buildXmlTestSystemOut(TestCase testCase, XmlBuilder xmlBuilder) {
    if(_messagesByTestCase.containsKey(testCase)) {
      String output = _messagesByTestCase[testCase].join('\n');
      xmlBuilder.element("system-out", nest: () {
        xmlBuilder.text(output);
      });
    }
  }

  @override
  void onDone(bool success) {
    File testFile = new File("${_outputPath}/darttest-${_className}.xml");
    testFile.writeAsStringSync(_output.toString(), mode: FileMode.WRITE, flush: true);

    // FIXME: Why?
    // override to avoid a call to "_postMessage(String)"
    _receivePort.close();
    _output = null;
  }

  String _escapeXml(String value) {
    return value.replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;');
  }

  bool get autoStart => _autoStart;
  bool _autoStart = true;

  StringSink _output;
  String _outputPath;
  String _className;

  ReceivePort _receivePort;
  Map<TestCase, List<String>> _messagesByTestCase;

  final DateTime _testStartTime;
  final String _hostname;
}