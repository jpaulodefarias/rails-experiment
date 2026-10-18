# Rails Experiment API

API REST em Rails 8.1, Ruby 3.4 e PostgreSQL 18. O desenho e as decisões iniciais estão em [SDD.md](SDD.md).

## Desenvolvimento

Use VS Code com a extensão Dev Containers e Docker Desktop. Abra a pasta no Dev Container. O Compose inicia a aplicação, o PostgreSQL, o Kafka e o publicador de eventos; o comando de criação prepara o banco. A API fica em `http://localhost:3000`.

O Dev Container instala automaticamente **Ruby LSP** (análise, navegação, formatação e suporte a Rails) e **Rails Fast Nav** (navegação entre arquivos Rails). Após alterar `.devcontainer/devcontainer.json`, execute **Dev Containers: Rebuild Container** no VS Code para instalar as extensões. O Ruby LSP pode criar a pasta local `.ruby-lsp/`, que está ignorada pelo Git.

Pelo terminal do container:

```sh
bundle install
bin/rails db:prepare
bin/rails server -b 0.0.0.0
bin/rails test
bundle exec rubocop
```

Sem VS Code, execute `docker compose run --build --rm app bundle install`, depois `docker compose run --rm app bin/rails db:prepare` e então `docker compose up`. Para testes, use `docker compose run --rm app bin/rails test`. Os dados locais ficam no volume `pgdata`. A senha `rails_local_only` serve apenas ao ambiente local.

Ao alterar dependências, execute `bundle install` e inclua o `Gemfile.lock` atualizado no controle de versão. As imagens de desenvolvimento e produção usam esse arquivo para instalações reproduzíveis.

## Eventos de usuários no Kafka

Toda criação, atualização ou exclusão bem-sucedida de um usuário registra um evento na tabela `user_events`, na mesma transação do banco. A exclusão da coleção registra um evento `deleted` para cada usuário removido. Requisições inválidas não geram eventos. Um processo `event_dispatcher` publica os eventos pendentes no tópico `user.events.v1`; a chave Kafka é o ID do usuário em texto, mantendo eventos do mesmo usuário na mesma partição.

Exemplo de mensagem JSON:

```json
{
  "eventId": "60db76d2-cf72-4ea2-94a2-997294407826",
  "action": "updated",
  "occurredAt": "2026-10-17T21:00:00.000Z",
  "user": {
    "id": 1,
    "name": "Ana",
    "email": "ana@example.com",
    "created_at": "2026-10-17T20:00:00.000Z",
    "updated_at": "2026-10-17T21:00:00.000Z"
  }
}
```

Para `deleted`, `user` contém os últimos dados antes da exclusão. A resposta HTTP confirma o registro no banco e na fila de saída, não a entrega ao Kafka. Se o broker falhar, o processo tenta novamente e o evento permanece pendente. A entrega é **pelo menos uma vez**: uma falha entre a confirmação do Kafka e a marcação do evento como publicado pode gerar duplicatas. Consumidores devem deduplicar por `eventId`.

O Compose cria o tópico e usa um volume local para os dados do Kafka. Para conferir eventos, execute `docker compose exec kafka /opt/kafka/bin/kafka-console-consumer.sh --bootstrap-server kafka:9092 --topic user.events.v1 --from-beginning --formatter-property print.key=true`. `KAFKA_BOOTSTRAP_SERVERS` e `KAFKA_TOPIC` configuram o publicador fora do Compose. Em produção, execute uma instância de `bin/dispatch_user_events` como processo separado após as migrações e crie o tópico no cluster gerenciado. Monitore eventos pendentes em `user_events` e falhas `user_event_delivery_failed` nos logs.

## Contrato HTTP

Todas as rotas usam JSON. `GET /health` consulta o PostgreSQL e retorna `{"status":"UP"}` com 200 ou `{"status":"DOWN"}` com 503. A falha detalhada aparece apenas nos logs.

| Método | Rota | Resultado |
| --- | --- | --- |
| GET | `/api/v1/users` | Array de usuários; 200 |
| GET | `/api/v1/users/:id` | Usuário; 200 ou 404 |
| POST | `/api/v1/users` | Cria usuário; 201 ou 422 |
| PUT | `/api/v1/users/:id` | Atualiza os campos enviados; 200, 404 ou 422 |
| DELETE | `/api/v1/users/:id` | Exclui usuário; 204 ou 404 |
| DELETE | `/api/v1/users` | Exclui todos; 204, somente em development/test |

Envie `{"user":{"name":"Ana","email":"ana@example.com"}}` no POST e PUT. Nome e e-mail são obrigatórios na criação. O e-mail é normalizado para minúsculas e deve ser válido e único, sem distinção de maiúsculas e minúsculas. As respostas de usuário contêm `id`, `name`, `email`, `created_at` e `updated_at`; a listagem usa um array ordenado por `id`.

Erros usam `{"code":"VALIDATION_FAILED","message":"User is invalid","traceId":"...","fieldErrors":{"email":["..."]}}`. `fieldErrors` aparece nas falhas de validação. JSON malformado ou ausência do objeto `user` gera 400; registro ou rota ausente gera 404; validação gera 422; conflito detectado pelo índice único gera 409; falhas inesperadas geram 500 sem detalhes internos. `traceId` corresponde ao request ID do Rails.

## Configuração e operação

`DB_HOST`, `DB_PORT`, `DB_USER`, `DB_PASSWORD` e `DB_NAME` configuram o banco. `PORT`, `RAILS_MAX_THREADS` e `LOG_LEVEL` configuram a aplicação. Em produção, defina também `SECRET_KEY_BASE` por injeção segura de segredo. O Compose fornece apenas credenciais locais.

Os logs JSON incluem horário, severidade e mensagem; eventos HTTP incluem request ID, método, caminho, status e duração. Não registre corpos de requisições ou credenciais. Em implantação futura, forneça um PostgreSQL gerenciado, execute `bin/rails db:migrate` antes de servir tráfego e monitore `/health` e os logs. A escolha de plataforma, gestão de segredos e publicação estão fora desta entrega.

## Swagger / OpenAPI

Com a aplicação em execução, abra `http://localhost:3000/api-docs` para explorar e testar as rotas no Swagger UI. A especificação OpenAPI 3.0 está em [openapi/v1/openapi.yaml](openapi/v1/openapi.yaml) e também é servida em `http://localhost:3000/api-docs/v1/openapi.yaml`. A interface usa a origem da própria aplicação, portanto o botão **Try it out** envia requisições para a API local.

O endpoint `DELETE /api/v1/users`, que apaga a coleção inteira, existe apenas em `development` e `test`; em `production` ele retorna 404.
