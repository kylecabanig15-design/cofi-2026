# CoFi interaction feedback system

CoFi uses one interaction language across user, business, and admin surfaces.
New flows should reuse the components below instead of constructing standalone
Snackbars or confirmation dialogs.

## Feedback

Use `CustomToast` after a completed action or when the user can continue without
making a modal decision.

- `success`: the requested write completed. State what changed, not simply
  “successful.”
- `error`: the write failed. Explain what the user can do next and do not expose
  raw exceptions, Firebase codes, or internal implementation details.
- `warning`: input, permission, or another requirement needs attention.
- `info`: neutral state changes and reversible actions.
- Keep one feedback message visible at a time.
- Capture `ScaffoldMessengerState` before an asynchronous operation if the
  current route may close, then use `CustomToast.showFromMessenger`.
- Use an `Undo` action for quick, reversible removal instead of opening a modal.

## Confirmations

Use `CustomDialog.confirm` before actions with meaningful consequences:

- permanent deletion;
- archive, leave, sign out, clear-all, or privacy changes;
- publishing when it substantially changes public visibility.

Do not show a blocking success dialog after the action. Use `CustomToast` once
the write succeeds. Destructive dialogs must name the affected object, state the
consequence, use `Cancel` as the safe action, and use a specific primary label
such as `Delete offer` rather than `Yes` or `OK`.

## Buttons

- Use a specific verb: `Publish offer`, `Save changes`, `Delete response`.
- Disable the action during a write and keep a visible progress label.
- Primary actions use the shared dark-red fill with white text.
- Secondary actions use an outline and white text.
- Destructive styling belongs only to the final destructive action.
- Icon-only actions require a tooltip and a minimum 44 × 44 touch target.

## Timing and wording

- Success and information: about 3 seconds.
- Errors: about 5 seconds so recovery guidance can be read.
- Never announce success before the database or upload completes.
- Avoid “Oops,” “Error: …”, “Are you sure?”, and raw stack/service messages.
  Prefer a clear title, outcome, and next step.
