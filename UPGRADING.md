# Upgrading Notes

This document captures required refactoring on your part when upgrading to a module version that contains breaking changes.

## Upgrading to v1.0.0

### Variables

The following variables have been modified:

- `transit_gateway_route_table_propagation` type: list(string) -> map(string).
