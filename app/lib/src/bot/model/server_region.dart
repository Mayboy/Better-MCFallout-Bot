enum ServerRegion {
  defaultRegion('smp.nelsongx.com:20269'),

  nelsonsmp('smp.nelsongx.com:20269');

  final String host;
  const ServerRegion(this.host);

  String getName() {
    switch (this) {
      case ServerRegion.defaultRegion:
        return '預設區域';

      case ServerRegion.nelsonsmp:
        return 'nelsonsmp';
    }
  }
}
