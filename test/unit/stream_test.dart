import 'dart:async';

import 'package:batteries/batteries.dart';
import 'package:test/test.dart';

void main() => group('stream', () {
      test('relieve', () {
        const duration = Duration(microseconds: 150);
        bool isPrime(int n) {
          if (n > 1) {
            for (var i = 2; i < n; i++) {
              if (n % i != 0) continue;
              return false;
            }
            return true;
          } else {
            return false;
          }
        }

        final firstHundred = Iterable<int>.generate(100)
            .map<bool>(isPrime)
            .toList(growable: false);

        expectLater(
          Stream<int>.fromIterable(Iterable<int>.generate(100))
              .relieve(duration)
              .toList(),
          completes,
        );
        expectLater(
          Stream<int>.fromIterable(Iterable<int>.generate(100))
              .map<bool>(isPrime)
              .relieve(duration)
              .toList(),
          completion(firstHundred),
        );
        expectLater(
          Stream<int>.fromIterable(<int>[
            for (var i = 0; i < 100; i++) i,
          ]).map<bool>(isPrime).relieve(duration),
          emitsInOrder(firstHundred),
        );
        expectLater(
          Stream<int>.fromIterable(<int>[
            for (var i = 0; i < 100; i++) i,
          ]).map<bool>(isPrime).asBroadcastStream().relieve(duration),
          emitsInOrder(firstHundred),
        );
        expectLater(
          () async {
            int? value;
            Stream<int>.fromIterable(<int>[1, 2, 3])
                .asBroadcastStream()
                .map<int>((e) => value = e)
                .relieve(duration)
                .take(1);
            await Future<void>.delayed(duration * 2);
            return value;
          }(),
          completion(isNull),
        );
      });

      group('transformOnType', () {
        String sum(String a, String b) => a + b;
        test(
          'Untouched non-broadcast stream',
          () => expectLater(
            Stream<_A>.fromIterable(const [_B('a'), _B('a'), _B('a')])
                .transformOnType<_C>(
                  (cs) => cs.map((c) => c.value.toUpperCase()).map(_C.new),
                )
                .map((event) => event.value)
                .reduce(sum),
            completion('aaa'),
          ),
        );
        test(
          'Untouched broadcast stream',
          () => expectLater(
            Stream<_A>.fromIterable(const [_B('a'), _B('a'), _B('a')])
                .asBroadcastStream()
                .transformOnType<_C>(
                  (cs) => cs.map((c) => c.value.toUpperCase()).map(_C.new),
                )
                .map((event) => event.value)
                .reduce(sum),
            completion('aaa'),
          ),
        );
        test(
          'Transformed non-broadcast stream',
          () => expectLater(
            Stream<_A>.fromIterable(const [_B('a'), _C('A'), _B('a')])
                .transformOnType<_C>(
                  (cs) => cs.map((c) => c.value.toUpperCase()).map(_C.new),
                )
                .map((event) => event.value)
                .reduce(sum),
            completion('aAa'),
          ),
        );
        test(
          'Transformed broadcast stream',
          () => expectLater(
            Stream<_A>.fromIterable(const [_B('a'), _C('A'), _B('a')])
                .asBroadcastStream()
                .transformOnType<_C>(
                  (cs) => cs.map((c) => c.value.toUpperCase()).map(_C.new),
                )
                .map((event) => event.value)
                .reduce(sum),
            completion('aAa'),
          ),
        );
        test(
          'Transformer retains inertia stream contract on non-broadcast stream',
          () async {
            StreamSubscription<_A>? sub;
            var transformedHasEmitted = false;
            final controller = StreamController<_A>();
            final transformed = controller.stream
                .transformOnType<_C>((selected) => selected)
                .map((event) {
              transformedHasEmitted = true;
              return event;
            });

            Future<void> nextEventLoop() => Future<void>.delayed(Duration.zero);
            void emit() => controller.add(const _C('a'));
            void subscribe() => sub = transformed.listen((event) {});

            await nextEventLoop();
            expect(transformedHasEmitted, false);
            emit();
            await nextEventLoop();
            expect(transformedHasEmitted, false);
            subscribe();
            await nextEventLoop();
            expect(transformedHasEmitted, true);

            await sub?.cancel();
            await controller.close();
          },
        );
        test('Transformer retains inertia stream contract on broadcast stream',
            () async {
          StreamSubscription<_A>? sub;
          var transformedHasEmitted = false;
          final controller = StreamController<_A>.broadcast();
          final transformed = controller.stream
              .transformOnType<_C>((selected) => selected)
              .map((event) {
            transformedHasEmitted = true;
            return event;
          });

          Future<void> nextEventLoop() => Future<void>.delayed(Duration.zero);
          void emit() => controller.add(const _C('a'));
          void subscribe() => sub = transformed.listen((event) {});

          await nextEventLoop();
          expect(transformedHasEmitted, false);
          emit();
          await nextEventLoop();
          expect(transformedHasEmitted, false);
          subscribe();
          await nextEventLoop();
          expect(transformedHasEmitted, false);
          emit();
          await nextEventLoop();
          expect(transformedHasEmitted, true);

          await sub?.cancel();
          await controller.close();
        });
      });
      test('calm', () {
        const duration = Duration(microseconds: 150);
        final data = Iterable<int>.generate(10).toList(growable: false);
        expectLater(
          Stream<int>.fromIterable(data).calm(duration).toList(),
          completes,
        );
        expectLater(
          Stream<int>.fromIterable(<int>[]).calm(duration),
          neverEmits(anything),
        );
        expectLater(
          Stream<int>.fromIterable(data).calm(duration).toList(),
          completion(data),
        );
        expectLater(
          Stream<int>.fromIterable(data).calm(duration),
          emitsInOrder(data),
        );
        expectLater(
          () async {
            final sw = Stopwatch()..start();
            await Stream<int>.fromIterable(<int>[1, 2, 3])
                .calm(const Duration(milliseconds: 250))
                .take(3)
                .drain<void>();
            final elapsed = (sw..stop()).elapsedMilliseconds;
            return elapsed > 500 && elapsed < 750;
          }(),
          completion(isTrue),
        );
        expectLater(
          () async {
            int? value;
            Stream<int>.fromIterable(<int>[1, 2, 3])
                .asBroadcastStream()
                .map<int>((e) => value = e)
                .calm(duration)
                .take(1);
            await Future<void>.delayed(duration);
            return value;
          }(),
          completion(isNull),
        );
      });
    });

abstract class _A {
  final String value;

  const _A(this.value);
}

mixin _X {}

class _B = _A with _X;

class _C = _A with _X;
