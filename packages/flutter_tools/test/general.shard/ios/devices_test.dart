// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:flutter_tools/src/application_package.dart';
import 'package:flutter_tools/src/artifacts.dart';
import 'package:flutter_tools/src/base/file_system.dart';
import 'package:flutter_tools/src/base/io.dart';
import 'package:flutter_tools/src/base/logger.dart';
import 'package:flutter_tools/src/base/os.dart';
import 'package:flutter_tools/src/base/platform.dart';
import 'package:flutter_tools/src/build_info.dart';
import 'package:flutter_tools/src/cache.dart';
import 'package:flutter_tools/src/device.dart';
import 'package:flutter_tools/src/ios/devices.dart';
import 'package:flutter_tools/src/ios/ios_deploy.dart';
import 'package:flutter_tools/src/ios/ios_workflow.dart';
import 'package:flutter_tools/src/ios/mac.dart';
import 'package:flutter_tools/src/macos/xcode.dart';
import 'package:flutter_tools/src/mdns_discovery.dart';
import 'package:flutter_tools/src/project.dart';
import 'package:flutter_tools/src/reporting/reporting.dart';
import 'package:mockito/mockito.dart';
import 'package:vm_service/vm_service.dart';

import '../../src/common.dart';
import '../../src/context.dart';
import '../../src/mocks.dart';

class MockIOSApp extends Mock implements IOSApp {}
class MockArtifacts extends Mock implements Artifacts {}
class MockCache extends Mock implements Cache {}
class MockDirectory extends Mock implements Directory {}
class MockFileSystem extends Mock implements FileSystem {}
class MockIMobileDevice extends Mock implements IMobileDevice {}
class MockMDnsObservatoryDiscovery extends Mock implements MDnsObservatoryDiscovery {}
class MockXcode extends Mock implements Xcode {}
class MockFile extends Mock implements File {}
class MockPortForwarder extends Mock implements DevicePortForwarder {}
class MockUsage extends Mock implements Usage {}

void main() {
  final FakePlatform macPlatform = FakePlatform(operatingSystem: 'macos');
  final FakePlatform linuxPlatform = FakePlatform(operatingSystem: 'linux');
  final FakePlatform windowsPlatform = FakePlatform(operatingSystem: 'windows');

  group('IOSDevice', () {
    final List<Platform> unsupportedPlatforms = <Platform>[linuxPlatform, windowsPlatform];
    Artifacts mockArtifacts;
    MockCache mockCache;
    MockVmService mockVmService;
    Logger logger;
    IOSDeploy iosDeploy;
    IMobileDevice iMobileDevice;
    FileSystem mockFileSystem;

    setUp(() {
      mockArtifacts = MockArtifacts();
      mockCache = MockCache();
      mockVmService = MockVmService();
      const MapEntry<String, String> dyLdLibEntry = MapEntry<String, String>('DYLD_LIBRARY_PATH', '/path/to/libs');
      when(mockCache.dyLdLibEntry).thenReturn(dyLdLibEntry);
      logger = BufferLogger.test();
      iosDeploy = IOSDeploy(
        artifacts: mockArtifacts,
        cache: mockCache,
        logger: logger,
        platform: macPlatform,
        processManager: FakeProcessManager.any(),
      );
      iMobileDevice = IMobileDevice(
        artifacts: mockArtifacts,
        cache: mockCache,
        logger: logger,
        processManager: FakeProcessManager.any(),
      );
    });

    testWithoutContext('successfully instantiates on Mac OS', () {
      IOSDevice(
        'device-123',
        artifacts: mockArtifacts,
        fileSystem: mockFileSystem,
        logger: logger,
        platform: macPlatform,
        iosDeploy: iosDeploy,
        iMobileDevice: iMobileDevice,
        name: 'iPhone 1',
        sdkVersion: '13.3',
        cpuArchitecture: DarwinArch.arm64,
        interfaceType: IOSDeviceInterface.usb,
        vmServiceConnectUri: (String string, {Log log}) async => mockVmService,
      );
    });

    testWithoutContext('parses major version', () {
      expect(IOSDevice(
        'device-123',
        artifacts: mockArtifacts,
        fileSystem: mockFileSystem,
        logger: logger,
        platform: macPlatform,
        iosDeploy: iosDeploy,
        iMobileDevice: iMobileDevice,
        name: 'iPhone 1',
        cpuArchitecture: DarwinArch.arm64,
        sdkVersion: '1.0.0',
        interfaceType: IOSDeviceInterface.usb,
        vmServiceConnectUri: (String string, {Log log}) async => mockVmService,
      ).majorSdkVersion, 1);
      expect(IOSDevice(
        'device-123',
        artifacts: mockArtifacts,
        fileSystem: mockFileSystem,
        logger: logger,
        platform: macPlatform,
        iosDeploy: iosDeploy,
        iMobileDevice: iMobileDevice,
        name: 'iPhone 1',
        cpuArchitecture: DarwinArch.arm64,
        sdkVersion: '13.1.1',
        interfaceType: IOSDeviceInterface.usb,
        vmServiceConnectUri: (String string, {Log log}) async => mockVmService,
      ).majorSdkVersion, 13);
      expect(IOSDevice(
        'device-123',
        artifacts: mockArtifacts,
        fileSystem: mockFileSystem,
        logger: logger,
        platform: macPlatform,
        iosDeploy: iosDeploy,
        iMobileDevice: iMobileDevice,
        name: 'iPhone 1',
        cpuArchitecture: DarwinArch.arm64,
        sdkVersion: '10',
        interfaceType: IOSDeviceInterface.usb,
        vmServiceConnectUri: (String string, {Log log}) async => mockVmService,
      ).majorSdkVersion, 10);
      expect(IOSDevice(
        'device-123',
        artifacts: mockArtifacts,
        fileSystem: mockFileSystem,
        logger: logger,
        platform: macPlatform,
        iosDeploy: iosDeploy,
        iMobileDevice: iMobileDevice,
        name: 'iPhone 1',
        cpuArchitecture: DarwinArch.arm64,
        sdkVersion: '0',
        interfaceType: IOSDeviceInterface.usb,
        vmServiceConnectUri: (String string, {Log log}) async => mockVmService,
      ).majorSdkVersion, 0);
      expect(IOSDevice(
        'device-123',
        artifacts: mockArtifacts,
        fileSystem: mockFileSystem,
        logger: logger,
        platform: macPlatform,
        iosDeploy: iosDeploy,
        iMobileDevice: iMobileDevice,
        name: 'iPhone 1',
        cpuArchitecture: DarwinArch.arm64,
        sdkVersion: 'bogus',
        interfaceType: IOSDeviceInterface.usb,
        vmServiceConnectUri: (String string, {Log log}) async => mockVmService,
      ).majorSdkVersion, 0);
    });

    testWithoutContext('Supports debug, profile, and release modes', () {
      final IOSDevice device = IOSDevice(
        'device-123',
        artifacts: mockArtifacts,
        fileSystem: mockFileSystem,
        logger: logger,
        platform: macPlatform,
        iosDeploy: iosDeploy,
        iMobileDevice: iMobileDevice,
        name: 'iPhone 1',
        sdkVersion: '13.3',
        cpuArchitecture: DarwinArch.arm64,
        interfaceType: IOSDeviceInterface.usb,
        vmServiceConnectUri: (String string, {Log log}) async => mockVmService,
      );

      expect(device.supportsRuntimeMode(BuildMode.debug), true);
      expect(device.supportsRuntimeMode(BuildMode.profile), true);
      expect(device.supportsRuntimeMode(BuildMode.release), true);
      expect(device.supportsRuntimeMode(BuildMode.jitRelease), false);
    });

    for (final Platform platform in unsupportedPlatforms) {
      testWithoutContext('throws UnsupportedError exception if instantiated on ${platform.operatingSystem}', () {
        expect(
          () {
            IOSDevice(
              'device-123',
              artifacts: mockArtifacts,
              fileSystem: mockFileSystem,
              logger: logger,
              platform: platform,
              iosDeploy: iosDeploy,
              iMobileDevice: iMobileDevice,
              name: 'iPhone 1',
              sdkVersion: '13.3',
              cpuArchitecture: DarwinArch.arm64,
              interfaceType: IOSDeviceInterface.usb,
              vmServiceConnectUri: (String string, {Log log}) async => mockVmService,
            );
          },
          throwsAssertionError,
        );
      });
    }

    group('.dispose()', () {
      IOSDevice device;
      MockIOSApp appPackage1;
      MockIOSApp appPackage2;
      IOSDeviceLogReader logReader1;
      IOSDeviceLogReader logReader2;
      MockProcess mockProcess1;
      MockProcess mockProcess2;
      MockProcess mockProcess3;
      IOSDevicePortForwarder portForwarder;
      ForwardedPort forwardedPort;
      Artifacts mockArtifacts;
      MockCache mockCache;
      MockFileSystem mockFileSystem;
      MockProcessManager mockProcessManager;
      MockDeviceLogReader mockLogReader;
      MockMDnsObservatoryDiscovery mockMDnsObservatoryDiscovery;
      MockPortForwarder mockPortForwarder;
      MockUsage mockUsage;

      const int devicePort = 499;
      const int hostPort = 42;
      const String installerPath = '/path/to/ideviceinstaller';
      const String iosDeployPath = '/path/to/iosdeploy';
      // const String appId = '789';
      const MapEntry<String, String> libraryEntry = MapEntry<String, String>(
          'DYLD_LIBRARY_PATH',
          '/path/to/libraries'
      );
      final Map<String, String> env = Map<String, String>.fromEntries(
          <MapEntry<String, String>>[libraryEntry]
      );

      setUp(() {
        appPackage1 = MockIOSApp();
        appPackage2 = MockIOSApp();
        when(appPackage1.name).thenReturn('flutterApp1');
        when(appPackage2.name).thenReturn('flutterApp2');
        mockProcess1 = MockProcess();
        mockProcess2 = MockProcess();
        mockProcess3 = MockProcess();
        forwardedPort = ForwardedPort.withContext(123, 456, mockProcess3);
        mockArtifacts = MockArtifacts();
        mockCache = MockCache();
        when(mockCache.dyLdLibEntry).thenReturn(libraryEntry);
        mockFileSystem = MockFileSystem();
        mockMDnsObservatoryDiscovery = MockMDnsObservatoryDiscovery();
        mockProcessManager = MockProcessManager();
        mockLogReader = MockDeviceLogReader();
        mockPortForwarder = MockPortForwarder();
        mockUsage = MockUsage();

        when(
            mockArtifacts.getArtifactPath(
                Artifact.ideviceinstaller,
                platform: anyNamed('platform'),
            )
        ).thenReturn(installerPath);

        when(
            mockArtifacts.getArtifactPath(
                Artifact.iosDeploy,
                platform: anyNamed('platform'),
            )
        ).thenReturn(iosDeployPath);

        when(mockPortForwarder.forward(devicePort, hostPort: anyNamed('hostPort')))
          .thenAnswer((_) async => hostPort);
        when(mockPortForwarder.forwardedPorts)
          .thenReturn(<ForwardedPort>[ForwardedPort(hostPort, devicePort)]);
        when(mockPortForwarder.unforward(any))
          .thenAnswer((_) async => null);

        const String bundlePath = '/path/to/bundle';
        final List<String> installArgs = <String>[installerPath, '-i', bundlePath];
        when(mockApp.deviceBundlePath).thenReturn(bundlePath);
        final MockDirectory directory = MockDirectory();
        when(mockFileSystem.directory(bundlePath)).thenReturn(directory);
        when(directory.existsSync()).thenReturn(true);
        when(mockProcessManager.run(installArgs, environment: env))
            .thenAnswer(
                (_) => Future<ProcessResult>.value(ProcessResult(1, 0, '', ''))
            );
      });

      tearDown(() {
        mockLogReader.dispose();
      });

      testUsingContext(' succeeds in debug mode via mDNS', () async {
        final IOSDevice device = IOSDevice('123');
        device.portForwarder = mockPortForwarder;
        device.setLogReader(mockApp, mockLogReader);
        final Uri uri = Uri(
          scheme: 'http',
          host: '127.0.0.1',
          port: 1234,
          path: 'observatory',
        );
        when(mockMDnsObservatoryDiscovery.getObservatoryUri(any, any, any))
          .thenAnswer((Invocation invocation) => Future<Uri>.value(uri));

        final LaunchResult launchResult = await device.startApp(mockApp,
          prebuiltApplication: true,
          debuggingOptions: DebuggingOptions.enabled(const BuildInfo(BuildMode.debug, null)),
          platformArgs: <String, dynamic>{},
        );
        verify(mockUsage.sendEvent('ios-mdns', 'success')).called(1);
        expect(launchResult.started, isTrue);
        expect(launchResult.hasObservatory, isTrue);
        expect(await device.stopApp(mockApp), isFalse);
      }, overrides: <Type, Generator>{
        Artifacts: () => mockArtifacts,
        Cache: () => mockCache,
        FileSystem: () => mockFileSystem,
        MDnsObservatoryDiscovery: () => mockMDnsObservatoryDiscovery,
        Platform: () => macPlatform,
        ProcessManager: () => mockProcessManager,
        Usage: () => mockUsage,
      });

      testUsingContext(' succeeds in debug mode when mDNS fails by falling back to manual protocol discovery', () async {
        final IOSDevice device = IOSDevice('123');
        device.portForwarder = mockPortForwarder;
        device.setLogReader(mockApp, mockLogReader);
        // Now that the reader is used, start writing messages to it.
        Timer.run(() {
          mockLogReader.addLine('Foo');
          mockLogReader.addLine('Observatory listening on http://127.0.0.1:$devicePort');
        });
        when(mockMDnsObservatoryDiscovery.getObservatoryUri(any, any, any))
          .thenAnswer((Invocation invocation) => Future<Uri>.value(null));

        final LaunchResult launchResult = await device.startApp(mockApp,
          prebuiltApplication: true,
          debuggingOptions: DebuggingOptions.enabled(const BuildInfo(BuildMode.debug, null)),
          platformArgs: <String, dynamic>{},
        );
        verify(mockUsage.sendEvent('ios-mdns', 'failure')).called(1);
        verify(mockUsage.sendEvent('ios-mdns', 'fallback-success')).called(1);
        expect(launchResult.started, isTrue);
        expect(launchResult.hasObservatory, isTrue);
        expect(await device.stopApp(mockApp), isFalse);
      }, overrides: <Type, Generator>{
        Artifacts: () => mockArtifacts,
        Cache: () => mockCache,
        FileSystem: () => mockFileSystem,
        MDnsObservatoryDiscovery: () => mockMDnsObservatoryDiscovery,
        Platform: () => macPlatform,
        ProcessManager: () => mockProcessManager,
        Usage: () => mockUsage,
      });
    });
  });

      testUsingContext(' fails in debug mode when mDNS fails and when Observatory URI is malformed', () async {
        final IOSDevice device = IOSDevice('123');
        device.portForwarder = mockPortForwarder;
        device.setLogReader(mockApp, mockLogReader);

        // Now that the reader is used, start writing messages to it.
        Timer.run(() {
          mockLogReader.addLine('Foo');
          mockLogReader.addLine('Observatory listening on http:/:/127.0.0.1:$devicePort');
        });
        when(mockMDnsObservatoryDiscovery.getObservatoryUri(any, any, any))
          .thenAnswer((Invocation invocation) => Future<Uri>.value(null));

        final LaunchResult launchResult = await device.startApp(mockApp,
            prebuiltApplication: true,
            debuggingOptions: DebuggingOptions.enabled(const BuildInfo(BuildMode.debug, null)),
            platformArgs: <String, dynamic>{},
        );
        verify(mockUsage.sendEvent('ios-mdns', 'failure')).called(1);
        verify(mockUsage.sendEvent('ios-mdns', 'fallback-failure')).called(1);
        expect(launchResult.started, isFalse);
        expect(launchResult.hasObservatory, isFalse);
      }, overrides: <Type, Generator>{
        Artifacts: () => mockArtifacts,
        Cache: () => mockCache,
        FileSystem: () => mockFileSystem,
        MDnsObservatoryDiscovery: () => mockMDnsObservatoryDiscovery,
        Platform: () => macPlatform,
        ProcessManager: () => mockProcessManager,
        Usage: () => mockUsage,
      });

      testUsingContext(' succeeds in release mode', () async {
        final IOSDevice device = IOSDevice('123');
        final LaunchResult launchResult = await device.startApp(mockApp,
          prebuiltApplication: true,
          debuggingOptions: DebuggingOptions.disabled(const BuildInfo(BuildMode.release, null)),
          platformArgs: <String, dynamic>{},
        );
        expect(launchResult.started, isTrue);
        expect(launchResult.hasObservatory, isFalse);
        expect(await device.stopApp(mockApp), isFalse);
      }, overrides: <Type, Generator>{
        Artifacts: () => mockArtifacts,
        Cache: () => mockCache,
        FileSystem: () => mockFileSystem,
        Platform: () => macPlatform,
        ProcessManager: () => mockProcessManager,
      });
    });

    testWithoutContext('start polling without Xcode', () async {
      final IOSDevices iosDevices = IOSDevices(
        platform: macPlatform,
        xcdevice: mockXcdevice,
        iosWorkflow: mockIosWorkflow,
        logger: logger,
      );
      when(mockXcdevice.isInstalled).thenReturn(false);

      await iosDevices.startPolling();
      verifyNever(mockXcdevice.getAvailableIOSDevices());
    });

    testWithoutContext('start polling', () async {
      final IOSDevices iosDevices = IOSDevices(
        platform: macPlatform,
        xcdevice: mockXcdevice,
        iosWorkflow: mockIosWorkflow,
        logger: logger,
      );
      when(mockXcdevice.isInstalled).thenReturn(true);

      int fetchDevicesCount = 0;
      when(mockXcdevice.getAvailableIOSDevices())
        .thenAnswer((Invocation invocation) {
          if (fetchDevicesCount == 0) {
            // Initial time, no devices.
            fetchDevicesCount++;
            return Future<List<IOSDevice>>.value(<IOSDevice>[]);
          } else if (fetchDevicesCount == 1) {
            // Simulate 2 devices added later.
            fetchDevicesCount++;
            return Future<List<IOSDevice>>.value(<IOSDevice>[device1, device2]);
          }
          fail('Too many calls to getAvailableTetheredIOSDevices');
      });

      int addedCount = 0;
      final Completer<void> added = Completer<void>();
      iosDevices.onAdded.listen((Device device) {
        addedCount++;
        // 2 devices will be added.
        // Will throw over-completion if called more than twice.
        if (addedCount >= 2) {
          added.complete();
        }
      });

      final Completer<void> removed = Completer<void>();
      iosDevices.onRemoved.listen((Device device) {
        // Will throw over-completion if called more than once.
        removed.complete();
      });

      final StreamController<Map<XCDeviceEvent, String>> eventStream = StreamController<Map<XCDeviceEvent, String>>();
      when(mockXcdevice.observedDeviceEvents()).thenAnswer((_) => eventStream.stream);

      await iosDevices.startPolling();
      verify(mockXcdevice.getAvailableIOSDevices()).called(1);

      expect(iosDevices.deviceNotifier.items, isEmpty);
      expect(eventStream.hasListener, isTrue);

      eventStream.add(<XCDeviceEvent, String>{
        XCDeviceEvent.attach: 'd83d5bc53967baa0ee18626ba87b6254b2ab5418'
      });
      await added.future;
      expect(iosDevices.deviceNotifier.items.length, 2);
      expect(iosDevices.deviceNotifier.items, contains(device1));
      expect(iosDevices.deviceNotifier.items, contains(device2));

      eventStream.add(<XCDeviceEvent, String>{
        XCDeviceEvent.detach: 'd83d5bc53967baa0ee18626ba87b6254b2ab5418'
      });
      await removed.future;
      expect(iosDevices.deviceNotifier.items, <Device>[device2]);

      // Remove stream will throw over-completion if called more than once
      // which proves this is ignored.
      eventStream.add(<XCDeviceEvent, String>{
        XCDeviceEvent.detach: 'bogus'
      });

      expect(addedCount, 2);

      await iosDevices.stopPolling();

      expect(eventStream.hasListener, isFalse);
    });

    testWithoutContext('polling can be restarted if stream is closed', () async {
      final IOSDevices iosDevices = IOSDevices(
        platform: macPlatform,
        xcdevice: mockXcdevice,
        iosWorkflow: mockIosWorkflow,
        logger: logger,
      );
      when(mockXcdevice.isInstalled).thenReturn(true);

      when(mockXcdevice.getAvailableIOSDevices())
        .thenAnswer((Invocation invocation) => Future<List<IOSDevice>>.value(<IOSDevice>[]));

      final StreamController<Map<XCDeviceEvent, String>> eventStream = StreamController<Map<XCDeviceEvent, String>>();
      final StreamController<Map<XCDeviceEvent, String>> rescheduledStream = StreamController<Map<XCDeviceEvent, String>>();

      bool reschedule = false;
      when(mockXcdevice.observedDeviceEvents()).thenAnswer((Invocation invocation) {
        if (!reschedule) {
          reschedule = true;
          return eventStream.stream;
        }
        return rescheduledStream.stream;
      });

      await iosDevices.startPolling();
      expect(eventStream.hasListener, isTrue);
      verify(mockXcdevice.getAvailableIOSDevices()).called(1);

      // Pretend xcdevice crashed.
      await eventStream.close();
      expect(logger.traceText, contains('xcdevice observe stopped'));

      // Confirm a restart still gets streamed events.
      await iosDevices.startPolling();

      expect(eventStream.hasListener, isFalse);
      expect(rescheduledStream.hasListener, isTrue);

      await iosDevices.stopPolling();
      expect(rescheduledStream.hasListener, isFalse);
    });

    testWithoutContext('dispose cancels polling subscription', () async {
      final IOSDevices iosDevices = IOSDevices(
        platform: macPlatform,
        xcdevice: mockXcdevice,
        iosWorkflow: mockIosWorkflow,
        logger: logger,
      );
      when(mockXcdevice.isInstalled).thenReturn(true);
      when(mockXcdevice.getAvailableIOSDevices())
          .thenAnswer((Invocation invocation) => Future<List<IOSDevice>>.value(<IOSDevice>[]));

      final StreamController<Map<XCDeviceEvent, String>> eventStream = StreamController<Map<XCDeviceEvent, String>>();
      when(mockXcdevice.observedDeviceEvents()).thenAnswer((_) => eventStream.stream);

      await iosDevices.startPolling();
      expect(iosDevices.deviceNotifier.items, isEmpty);
      expect(eventStream.hasListener, isTrue);

      await iosDevices.dispose();
      expect(eventStream.hasListener, isFalse);
    });

    final List<Platform> unsupportedPlatforms = <Platform>[linuxPlatform, windowsPlatform];
    for (final Platform unsupportedPlatform in unsupportedPlatforms) {
      testWithoutContext('pollingGetDevices throws Unsupported Operation exception on ${unsupportedPlatform.operatingSystem}', () async {
        final IOSDevices iosDevices = IOSDevices(
          platform: unsupportedPlatform,
          xcdevice: mockXcdevice,
          iosWorkflow: mockIosWorkflow,
          logger: logger,
        );
        when(mockXcdevice.isInstalled).thenReturn(false);
        expect(
            () async { await iosDevices.pollingGetDevices(); },
            throwsA(isA<UnsupportedError>()),
        );
      });
    }

    testWithoutContext('pollingGetDevices returns attached devices', () async {
      final IOSDevices iosDevices = IOSDevices(
        platform: macPlatform,
        xcdevice: mockXcdevice,
        iosWorkflow: mockIosWorkflow,
        logger: logger,
      );
      when(mockXcdevice.isInstalled).thenReturn(true);

      when(mockXcdevice.getAvailableIOSDevices())
          .thenAnswer((Invocation invocation) => Future<List<IOSDevice>>.value(<IOSDevice>[device1]));

      final List<Device> devices = await iosDevices.pollingGetDevices();
      expect(devices, hasLength(1));
      expect(identical(devices.first, device1), isTrue);
    });
  });

  group('getDiagnostics', () {
    MockXcdevice mockXcdevice;
    IOSWorkflow mockIosWorkflow;
    Logger logger;

    setUp(() {
      mockXcdevice = MockXcdevice();
      mockIosWorkflow = MockIOSWorkflow();
      logger = BufferLogger.test();
    });

    final List<Platform> unsupportedPlatforms = <Platform>[linuxPlatform, windowsPlatform];
    for (final Platform unsupportedPlatform in unsupportedPlatforms) {
      testWithoutContext('throws returns platform diagnostic exception on ${unsupportedPlatform.operatingSystem}', () async {
        final IOSDevices iosDevices = IOSDevices(
          platform: unsupportedPlatform,
          xcdevice: mockXcdevice,
          iosWorkflow: mockIosWorkflow,
          logger: logger,
        );
        when(mockXcdevice.isInstalled).thenReturn(false);
        expect((await iosDevices.getDiagnostics()).first, 'Control of iOS devices or simulators only supported on macOS.');
      });
    }

    testWithoutContext('returns diagnostics', () async {
      final IOSDevices iosDevices = IOSDevices(
        platform: macPlatform,
        xcdevice: mockXcdevice,
        iosWorkflow: mockIosWorkflow,
        logger: logger,
      );
      when(mockXcdevice.isInstalled).thenReturn(true);
      when(mockXcdevice.getDiagnostics())
          .thenAnswer((Invocation invocation) => Future<List<String>>.value(<String>['Generic pairing error']));

      final List<String> diagnostics = await iosDevices.getDiagnostics();
      expect(diagnostics, hasLength(1));
      expect(diagnostics.first, 'Generic pairing error');
    });
  });
}

class MockIOSApp extends Mock implements IOSApp {}
class MockArtifacts extends Mock implements Artifacts {}
class MockCache extends Mock implements Cache {}
class MockIMobileDevice extends Mock implements IMobileDevice {}
class MockIOSDeploy extends Mock implements IOSDeploy {}
class MockIOSWorkflow extends Mock implements IOSWorkflow {}
class MockXcdevice extends Mock implements XCDevice {}
class MockVmService extends Mock implements VmService {}
