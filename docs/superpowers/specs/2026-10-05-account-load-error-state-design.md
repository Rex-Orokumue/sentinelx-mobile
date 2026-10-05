# Account load error state design

**Date:** 2026-10-05

## Problem

`AccountScreen` currently reduces `meProvider` to `asData?.value`. Loading,
failure, and a successful signed-out `null` response therefore all render the
same Log in / Create account actions. During profile-onboarding verification,
an authenticated `/me` response failed contract validation and the Account tab
incorrectly told the player to log in again.

## Behavior

Render each `meProvider` state distinctly:

- Loading: show a centered progress indicator.
- Successful `null`: show the existing Log in and Create account actions.
- Successful non-null value: show the existing signed-in account controls.
- Error: show localized account-load failure copy and a Retry button. Retry
  invalidates `meProvider`; it must not show either authentication action.

This change does not infer authentication from cached profile data, add an
automatic retry loop, or change session lifecycle behavior.

## Localization

Add the following strings directly to the English template and French ARB,
because this account error has no corresponding web message namespace:

- `accountLoadFailed`: `Couldn't load your account.`
- `accountRetry`: `Retry`
- `accountLoadFailed` (French): `Impossible de charger votre compte.`
- `accountRetry` (French): `Réessayer`

Regenerate Flutter localization output.

## Testing

Widget regressions will prove:

1. A failed `meProvider` shows the error and Retry, with no Log in/Create
   account actions.
2. Tapping Retry invalidates and refetches `meProvider`, then renders the
   signed-in profile when the next request succeeds.
3. Existing signed-out and signed-in behavior remains unchanged.
