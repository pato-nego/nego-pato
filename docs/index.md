# Pato Nego

A buyer registers through Gateway, signs in, and orders products priced in US dollars. The order belongs to that buyer. When the buyer asks for a total in Brazilian reais, Order calls Exchange for the Banco Central do Brasil PTAX sell rate. The stored price stays in dollars.

## Demonstrated purchase

On November 20, 2026, the public EC2 gateway accepted an order for two units at USD 4.25. The order list and detail both showed USD 8.50. At the quoted rate of 5.8889, Order returned BRL 50.06. A second signed-in account received 404 for the same order and had an empty order list. The test accounts and product were removed after the check.

## Services and source

| Responsibility | Repository |
| --- | --- |
| Project integration and Compose | [nego-pato](https://github.com/pato-nego/nego-pato) |
| Authenticate and route traffic | [Gateway-service](https://github.com/pato-nego/Gateway-service) |
| Register users, issue and validate login cookies | [Auth-service](https://github.com/pato-nego/Auth-service) and [Auth contract](https://github.com/pato-nego/Auth) |
| Store accounts and password hashes in PostgreSQL | [Account-service](https://github.com/pato-nego/Account-service) and [Account contract](https://github.com/pato-nego/Account) |
| Fetch and cache PTAX quotes | [Exchange](https://github.com/pato-nego/Exchange) |
| Store and cache catalog products | [Product](https://github.com/pato-nego/Product) |
| Save orders, enforce ownership and convert totals | [Order-service](https://github.com/pato-nego/Order-service) and [Order contract](https://github.com/pato-nego/Order) |

Matheus Luciano owns Exchange. The Product and Order owners maintain their repositories and deployments. The group presentation should show the authenticated purchase, then the order in USD and BRL. The Kubernetes demonstration also needs all five listed services healthy in one cluster and the load test alongside the HPA. [Course delivery instructions](https://insper.github.io/platform/2026.2/exercises/project/presentation/)

## AI assistance

AI assisted with Python Exchange, Gateway integration, Kubernetes manifests, infrastructure configuration, CI configuration, end-to-end verification and this documentation. The test figures come from recorded runs. Individual members should credit their own contributions in their personal submissions.
