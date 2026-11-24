# Uploading Shots from an agent

Upload player photos and illustrations to the AthleteAce Shot API. Use the URL and credential for the intended AthleteAce environment.

Issue a credential in the target environment with
`bin/rails 'shots:issue_token[Portrait agent]'`. The command prints the token ID
and the bearer secret once. Give the secret to the agent through its secret
store. To revoke access, run `bin/rails 'shots:revoke_token[TOKEN_ID]'` in the
same environment.

Send one multipart request per file. The `metadata` part is a JSON object.
Both `tags` and `captures` may be omitted. A Capture accepts a local Player
entity code, its `MIC-ALA-` form, or a registered alias. Weight defaults to 1.

```bash
curl --fail-with-body "$ATHLETEACE_URL/api/v1/shots" \
  -H "Authorization: Bearer $SHOT_UPLOAD_TOKEN" \
  -H "Idempotency-Key: portrait-2026-001" \
  -F 'image=@portrait.png' \
  --form-string 'metadata={"tags":["portrait"],"captures":[{"player_entity_code":"PLAYER-EXAMPLE","weight":4}]}'
```

Keep the same key and payload when retrying a file. The endpoint returns
`201` for a new Shot, `200` for a replay, or `409` if the same token reuses a key
with a different payload. The response includes the Shot ID, image path,
tags, and Captures with their weights and canonical Player codes. Images
may be up to 25 MB. An invalid image, tag, player code, or weight rejects
the upload as a whole.
