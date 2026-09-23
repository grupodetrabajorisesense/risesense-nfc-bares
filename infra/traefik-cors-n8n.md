# CORS en Traefik para n8n

Los webhooks de n8n (`/bar/carta`, `/bar/pedido`, etc.) necesitan responder correctamente
a las peticiones OPTIONS de preflight CORS que hacen los navegadores antes de un POST
con `Content-Type: application/json` desde otro dominio.

**Problema encontrado:** n8n gestiona internamente el `OPTIONS` en los webhooks de forma
que no respeta bien la opción "Allowed Origins (CORS)" configurada en el nodo — devuelve
un 204 vacío sin headers CORS completos.

**Solución:** middleware de CORS a nivel de Traefik, delante de n8n, para que sea Traefik
quien resuelva el preflight directamente. Configurado en
`/opt/risesense/n8n/docker-compose.yml`, labels del servicio:

\`\`\`yaml
- "traefik.http.middlewares.n8n-cors.headers.accesscontrolallowmethods=GET,POST,OPTIONS"
- "traefik.http.middlewares.n8n-cors.headers.accesscontrolallowheaders=Content-Type"
- "traefik.http.middlewares.n8n-cors.headers.accesscontrolalloworiginlist=*"
- "traefik.http.middlewares.n8n-cors.headers.accesscontrolmaxage=86400"
- "traefik.http.middlewares.n8n-cors.headers.addvaryheader=true"
- "traefik.http.routers.n8n.middlewares=n8n-cors"
- "traefik.http.routers.n8n-http.middlewares=n8n-cors"
\`\`\`

Aplicado con `docker compose up -d` en `/opt/risesense/n8n/`.

**Nota:** si en el futuro se restringe `accesscontrolalloworiginlist` a un dominio
concreto (en vez de `*`), recordar que debe incluir tanto el dominio de producción
del frontend como los de test/staging que se usen.
