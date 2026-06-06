# NexaLink CPQ Architecture Guide — v3

## Quote-to-Email Workflow

Hybrid manual + automated:

1. **PDF Generation (manual)** — sales rep clicks "Generate Document" on the Quote header, selecting the NexaLink template. CPQ generates the PDF via SBQQ.QuoteDocumentLoader and attaches it to the Quote's Files. The manual step gives reps explicit control over what is sent.

2. **Email Send (automated)** — when the rep sets Status to Presented or Approved, the SEND_QUOTE_VIA_EMAIL flow fires. The flow delegates to CPQQuoteEmailAction (Invocable), which enqueues CPQQuoteEmailQueueable. The Queueable resolves the customer Contact (most recent with email on the Account), reads the latest PDF from the Quote's Files, and sends a branded HTML email with the PDF attached via Messaging.SingleEmailMessage.

This follows Salesforce's recommended Quote-to-Cash pattern: keep the human review (PDF generation) explicit, automate only the mechanical step (email delivery).

### Component overview

| Component | Type | Role |
|---|---|---|
| SEND_QUOTE_VIA_EMAIL | AutoLaunched Flow | Triggers on Quote Status = Presented / Approved |
| CPQQuoteEmailAction | @InvocableMethod | Thin wrapper — enqueues Queueable, never throws to Flow |
| CPQQuoteEmailQueueable | Queueable (async) | Resolves contact, reads existing PDF from Files, sends email |

### Key design decisions

- **Async execution via Queueable** — decouples email delivery from the Flow transaction, preventing Flow fault-connector errors from email/PDF issues and staying within governor limits.
- **PDF sourced from Files** — relies on the PDF already attached by the rep via "Generate Document". The Queueable reads the most-recent PDF ContentVersion linked to the Quote via ContentDocumentLink. If none is found, the email is sent without attachment (graceful degradation).
- **Bulk-safe** — all SOQL runs before the per-quote loop; all DML (Messaging.sendEmail) runs after. Handles multiple Quote IDs in a single Queueable invocation.
- **No hardcoded IDs** — template lookup uses a LIKE pattern (`%NexaLink%`); contact lookup uses the Account relationship at runtime.
