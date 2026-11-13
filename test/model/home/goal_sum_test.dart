import 'package:coconut_wallet/model/home/home_widget_data.dart';
import 'package:flutter_test/flutter_test.dart';

HomeGoalShare _share(int id, {required int balance, int? target, String? account}) =>
    HomeGoalShare(walletId: id, name: 'w$id', balance: balance, target: target, accountKey: account);

void main() {
  group('HomeGoalSum (decision 7)', () {
    test('one account with different goals counts the balance once and the larger goal', () {
      // 목표 1·2 BTC, 잔액 1.5 BTC(같은 계정): 예전 합계는 3 / 3 BTC(100%), 이제 1.5 / 2 BTC(75%)
      final sum = HomeGoalSum.of([
        _share(1, balance: 150000000, target: 100000000, account: 'a'),
        _share(2, balance: 150000000, target: 200000000, account: 'a'),
      ]);
      expect(sum.balance, 150000000);
      expect(sum.target, 200000000);
      expect(sum.goal!.ratio, 0.75);
      expect(sum.hasConflictingGoals, isTrue);
      expect(sum.accounts.single.walletId, 2);
    });

    test('the same goal on one account counts once without a notice', () {
      final sum = HomeGoalSum.of([
        _share(1, balance: 40000000, target: 100000000, account: 'a'),
        _share(2, balance: 40000000, target: 100000000, account: 'a'),
      ]);
      expect((sum.balance, sum.target, sum.hasConflictingGoals), (40000000, 100000000, false));
      expect(sum.accounts.single.walletId, 1);
    });

    test('different accounts add up and wallets without a goal are left out', () {
      final sum = HomeGoalSum.of([
        _share(1, balance: 10000000, target: 50000000),
        _share(2, balance: 30000000, target: 100000000),
        _share(3, balance: 99000000),
      ]);
      expect((sum.balance, sum.target, sum.accounts.length), (40000000, 150000000, 2));
      expect(sum.hasConflictingGoals, isFalse);
    });

    test('the wallet that leads an account does not depend on the wallet order', () {
      final shares = [
        _share(1, balance: 1, target: 9, account: 'a'),
        _share(2, balance: 1, target: 5, account: 'a'),
        _share(3, balance: 1, target: 9, account: 'a'),
      ];
      expect(HomeGoalSum.of(shares).accounts.single.walletId, 1);
      expect(HomeGoalSum.of(shares.reversed).accounts.single.walletId, 1);
    });

    // B1-a: 같은 계정 지갑끼리 잔액이 다르면 큰 값이 아니라 작은 쪽 짝으로 보여 주고 달성은 미룬다(확인 대기)
    HomeGoalShare pair(int id, int total, {int? confirmed, int? target, bool synced = true}) => HomeGoalShare(
      walletId: id,
      name: 'w$id',
      balance: total,
      confirmedUnspent: confirmed,
      target: target,
      accountKey: 'a',
      synced: synced,
    );

    test('after a send the account shows the lower balance whichever wallet updated first', () {
      // Astra 예: 목표 1·1.2 BTC, 보낸 뒤 A는 0.4 BTC, 아직 모르는 B는 1.5 BTC
      for (final shares in [
        [pair(1, 40000000, target: 100000000), pair(2, 150000000, target: 120000000)],
        [pair(1, 150000000, target: 100000000), pair(2, 40000000, target: 120000000)],
      ]) {
        final sum = HomeGoalSum.of(shares);
        expect((sum.balance, sum.target), (40000000, 120000000));
        expect((sum.hasUnsettledAccounts, sum.reached, sum.awaitingConfirmation), (true, false, false));
      }
    });

    test('after a deposit the account waits instead of calling it reached until both wallets agree', () {
      final updatedFirst = HomeGoalSum.of([pair(1, 120000000, target: 100000000), pair(2, 80000000)]);
      expect((updatedFirst.balance, updatedFirst.reached, updatedFirst.hasUnsettledAccounts), (80000000, false, true));
      final staleFirst = HomeGoalSum.of([pair(1, 80000000, target: 100000000), pair(2, 120000000)]);
      expect((staleFirst.balance, staleFirst.reached), (80000000, false));
      final agreed = HomeGoalSum.of([pair(1, 120000000, target: 100000000), pair(2, 120000000)]);
      expect((agreed.balance, agreed.reached, agreed.hasUnsettledAccounts), (120000000, true, false));
    });

    test('a replacement with the same number of transactions still differs by the fee and waits', () {
      final sum = HomeGoalSum.of([pair(1, 99990000, target: 100000000), pair(2, 100000000)]);
      expect((sum.balance, sum.hasUnsettledAccounts, sum.reached), (99990000, true, false));
    });

    test('the same total with a different confirmed balance waits, using the pair of one wallet', () {
      final sum = HomeGoalSum.of([
        pair(1, 100000000, confirmed: 100000000, target: 100000000),
        pair(2, 100000000, confirmed: 80000000),
      ]);
      expect((sum.balance, sum.reachBalance, sum.hasUnsettledAccounts), (100000000, 80000000, true));
      expect((sum.reached, sum.awaitingConfirmation), (false, true));
    });

    test('a wallet removed and added again waits while it syncs, even when the balances look the same', () {
      final syncing = HomeGoalSum.of([pair(1, 50000000, target: 100000000), pair(3, 0, synced: false)]);
      expect((syncing.balance, syncing.hasUnsettledAccounts), (0, true));
      final sameButNotSynced = HomeGoalSum.of([pair(1, 50000000, target: 100000000), pair(3, 50000000, synced: false)]);
      expect(sameButNotSynced.hasUnsettledAccounts, isTrue);
      // 잔액은 같으니 '서로 달라'가 아니다(Fable C2). 다르면 그렇게 말한다
      expect((sameButNotSynced.hasDifferingBalances, syncing.hasDifferingBalances), (false, true));
    });

    test('a partial failure keeps the account waiting and the hold clears once every wallet syncs and agrees', () {
      final failed = HomeGoalSum.of([pair(1, 100000000, target: 100000000), pair(2, 100000000, synced: false)]);
      expect((failed.hasUnsettledAccounts, failed.reached, failed.allSynced), (true, false, false));
      final reconnected = HomeGoalSum.of([pair(1, 100000000, target: 100000000), pair(2, 100000000)]);
      expect((reconnected.hasUnsettledAccounts, reconnected.reached, reconnected.allSynced), (false, true, true));
    });

    test('a twin without a goal still counts for the check', () {
      final sum = HomeGoalSum.of([pair(1, 40000000, target: 100000000), pair(2, 150000000)]);
      expect((sum.balance, sum.hasUnsettledAccounts), (40000000, true));
    });

    test('a single wallet still syncing keeps its last balance but is not reached yet (decision 3)', () {
      // Astra B1-a.2: 마지막 확인값 1.5 BTC / 목표 1.2 BTC, 동기화 전. 숫자는 그대로, 달성은 동기화 뒤
      final sum = HomeGoalSum.of(const [
        HomeGoalShare(walletId: 1, name: 'w1', balance: 150000000, target: 120000000, synced: false),
      ]);
      expect((sum.balance, sum.hasUnsettledAccounts, sum.hasDifferingBalances), (150000000, false, false));
      expect((sum.reached, sum.awaitingConfirmation, sum.allSynced), (false, true, false));
      final synced = HomeGoalSum.of(const [
        HomeGoalShare(walletId: 1, name: 'w1', balance: 150000000, target: 120000000),
      ]);
      expect((synced.reached, synced.awaitingConfirmation), (true, false));
    });

    test('reached leaves out a deposit still waiting and counts a send still waiting', () {
      // 확인 0.9 + 확인 전 입금 0.2 = 1.1 BTC(목표 1 BTC): 아직 달성 아님, 확인 대기
      final deposit = HomeGoalSum.of(const [
        HomeGoalShare(walletId: 1, name: 'w1', balance: 110000000, confirmedUnspent: 90000000, target: 100000000),
      ]);
      expect((deposit.reached, deposit.awaitingConfirmation), (false, true));
      // 확인 1.1 가운데 0.2를 보내는 중 = 0.9 BTC: 바로 0.9로 센다
      final send = HomeGoalSum.of(const [
        HomeGoalShare(walletId: 1, name: 'w1', balance: 90000000, confirmedUnspent: 90000000, target: 100000000),
      ]);
      expect((send.reachBalance, send.reached, send.awaitingConfirmation), (90000000, false, false));
    });

    test('a deposit and a send waiting together do not reach the goal with the incoming coins', () {
      // Astra B1-a.1: 확인 1.1, 0.3 보내는 중, 0.2 들어오는 중 → 전체 1.0, 확인되고 남는 것 0.8. 목표 1 BTC
      final sum = HomeGoalSum.of(const [
        HomeGoalShare(walletId: 1, name: 'w1', balance: 100000000, confirmedUnspent: 80000000, target: 100000000),
      ]);
      expect((sum.balance, sum.reachBalance), (100000000, 80000000));
      expect((sum.reached, sum.awaitingConfirmation), (false, true));
    });

    // F1(B1-a.1): 주소 하나라도 확인 전 입출금이 남으면 달성을 미룬다. 보내는 중 목록이 빠져도(자기 앞 전송, 다시 만들다 난 오류)
    test('a pending address holds reached even when the coins being sent are missing from the subtraction', () {
      // 확인 1.1 BTC 가운데 0.3을 보내는 중, 0.2가 들어오는 중. outgoing 목록이 비어 confirmedUnspent가 1.1로 남았다
      final sum = HomeGoalSum.of(const [
        HomeGoalShare(
          walletId: 1,
          name: 'w1',
          balance: 100000000,
          confirmedUnspent: 110000000,
          target: 100000000,
          pending: true,
        ),
      ]);
      expect((sum.reachBalance, sum.hasPendingActivity), (100000000, true));
      expect((sum.reached, sum.awaitingConfirmation), (false, true));
    });

    test('a small pending deposit holds reached even when the confirmed balance is already enough', () {
      final sum = HomeGoalSum.of(const [
        HomeGoalShare(
          walletId: 1,
          name: 'w1',
          balance: 120001000,
          confirmedUnspent: 120000000,
          target: 100000000,
          pending: true,
        ),
      ]);
      expect((sum.reached, sum.awaitingConfirmation), (false, true));
    });

    test('a pending twin without a goal holds its account, and the hold clears once nothing is pending', () {
      HomeGoalShare twin(int id, {int? target, bool pending = false}) => HomeGoalShare(
        walletId: id,
        name: 'w$id',
        balance: 120000000,
        target: target,
        accountKey: 'a',
        pending: pending,
      );
      final held = HomeGoalSum.of([twin(1, target: 100000000), twin(2, pending: true)]);
      expect((held.reached, held.isSettled('a'), held.awaitingConfirmation), (false, false, true));
      // 확인되거나 멤풀에서 빠지면 주소별 unconfirmed가 0으로 돌아가 풀린다
      final released = HomeGoalSum.of([twin(1, target: 100000000), twin(2)]);
      expect((released.reached, released.isSettled('a')), (true, true));
    });

    test('no goal at all gives no goal', () {
      expect(HomeGoalSum.of([_share(1, balance: 5)]).goal, isNull);
    });
  });
}
