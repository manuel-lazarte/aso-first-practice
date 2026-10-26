#!/usr/bin/env python3
"""Validate explicit IPv4 laboratory networks; never accept special/non-RFC1918 ranges."""
import ipaddress
import sys

RFC1918 = tuple(ipaddress.ip_network(x) for x in (
    '10.0.0.0/8', '172.16.0.0/12', '192.168.0.0/16'))


def validate(value: str) -> ipaddress.IPv4Network:
    try:
        net = ipaddress.ip_network(value, strict=False)
    except ValueError as exc:
        raise ValueError(f'{value!r}: CIDR inválido') from exc
    if net.version != 4:
        raise ValueError(f'{value}: solo IPv4')
    if net.prefixlen < 24:
        raise ValueError(f'{value}: usar /24 a /32, nunca redes amplias')
    if not any(net.subnet_of(parent) for parent in RFC1918):
        raise ValueError(f'{value}: debe pertenecer completamente a RFC1918')
    return net


def main() -> int:
    if len(sys.argv) < 2:
        print('Uso: validate-lab-cidrs.py CIDR [CIDR...]', file=sys.stderr)
        return 2
    try:
        for cidr in sys.argv[1:]:
            validate(cidr)
    except ValueError as exc:
        print(f'ERROR DE SEGURIDAD: {exc}', file=sys.stderr)
        return 1
    print('CIDR IPv4 privados válidos')
    return 0


if __name__ == '__main__':
    sys.exit(main())
