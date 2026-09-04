# Flowcharts & Sequence

## Customer flow

```mermaid
flowchart TD
    A[Register / Login once] --> B[Browse upcoming sessions]
    B --> C[Join Interest]
    C --> D[Waiting for scheduled draw]
    D --> E{Selected in a wave?}
    E -- No --> D
    E -- Yes --> F[Resend invitation email]
    F --> G[Open invitation in Rembayung Access]
    G --> H{Authenticated owner + invitation valid?}
    H -- No --> I[Deny]
    H -- Yes --> J[Continue to UMAI]
    J --> K[UMAI handles final booking]
```

## Automatic batch broadcast

```mermaid
flowchart TD
    A[Scheduler tick] --> B[Find due scheduled wave]
    B --> C{Due wave exists?}
    C -- No --> Z[Stop]
    C -- Yes --> D[Lock / claim wave]
    D --> E[Fetch eligible active interests]
    E --> F[Random-first select up to wave_size]
    F --> G[Create invitations]
    G --> H[Mark interests selected]
    H --> I[Mark wave completed]
    I --> J[Dispatch pending emails via Resend]
    J --> K[Record delivery result]
```

## Invitation access

```mermaid
sequenceDiagram
    participant U as User
    participant E as Email
    participant W as Cloudflare Web
    participant S as Supabase
    participant M as UMAI

    E->>U: Invitation with /invite/:token
    U->>W: Open invitation
    W->>S: Validate token + authenticated user
    S-->>W: invitation valid / invalid
    W-->>U: Show Continue to UMAI
    U->>W: Continue
    W->>S: Audit redirect
    W-->>U: 302 redirect
    U->>M: Open UMAI booking
```

## Wave example

```mermaid
timeline
    title Scheduled release example
    21:00 : Wave 1 auto-selects random eligible users
    21:10 : Wave 1 invitation TTL/reconciliation point
    21:12 : Wave 2 releases automatically
    21:22 : Wave 2 reconciliation point
    21:24 : Wave 3 releases automatically
    21:34 : Release window completes
```
