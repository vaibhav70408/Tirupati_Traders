# Tirupati Traders App — Project Context & Handoff Notes

> **How to use this file:** Open a new Copilot Chat in this window and say:
> _"Read 03-Notes/PROJECT-CONTEXT.md and continue from the Next Step section."_
> The assistant will have full context and can pick up exactly where we left off.

---

## 1. About the business
- **Shop name:** Tirupati Traders
- **Type:** Provision / Kirana store (lentils/dals, rice, spices, oil, and many daily/monthly grocery items)
- **Goal:** A mobile app where customers can order daily & monthly grocery items, see available products, upload a handwritten list, and pay by UPI or cash. Owners approve orders before confirming.
- **Product count:** ~50–70 products
- **Admins:** Multiple (father, the user, and brother) — all can log in and approve orders.

---

## 2. Final decisions (agreed)
- **Frontend:** Flutter (single codebase for Android + iOS).
  - **Plan:** Build & test on **Android first**. Move to **iOS testing later** (iOS builds need a Mac at some stage).
- **Backend:** Firebase (Backend-as-a-Service) — chosen over Spring Boot for speed & simplicity.
  - Firebase Authentication (phone OTP for customers; login for admins)
  - Cloud Firestore (database: products, orders, users)
  - Firebase Storage (product images + uploaded handwritten list photos)
  - Firebase Cloud Messaging (push notifications to admins)
  - Cloud Functions (small logic: totals, and secure payment verification later)
- **Payments:** UPI (online) + Cash. Online via **Razorpay** (Phase 2). Cash on delivery/pickup.
- **App type:** ONE app, role-based login — customers see the shop; admins see the management dashboard.

---

## 3. Core features
**Customer:**
- Phone OTP login
- Browse catalog (categories: Dal, Rice, Spices, Oil, etc.), see out-of-stock items marked
- Cart + checkout
- Choose **Delivery or Pickup** (customer selects)
- Upload handwritten list (photo) — shop reads it manually and builds the order (NO AI at launch; AI is optional Phase 3)
- Pay by UPI or Cash
- Order status tracking: **Pending → Approved → Out for delivery / Ready → Completed**
- (Later) Order history + "Reorder last order"

**Admin (father / user / brother):**
- Admin login (multiple admins)
- Dashboard: today's sales, new orders, alerts
- Review & approve orders — tick items available, adjust qty/price for loose items (dal/rice/oil), remove out-of-stock items
- Read uploaded handwritten list and build the order from it
- Manage products: add/edit, mark in-stock/out-of-stock (toggle), **update price anytime**
- Get instant push notification on new orders

---

## 4. Order flow (summary)
1. Customer orders (browse+cart OR upload handwritten list) → chooses delivery/pickup
2. Order sent to admins → admins get notification
3. Admin reviews → approves items, adjusts qty/price, removes unavailable items → sends final bill
4. Customer pays (UPI online, or cash on delivery/pickup)
5. Order fulfilled → status updated → delivered/picked up → completed

---

## 5. Build roadmap (phases)
- **Phase 1 (MVP):** catalog, cart, checkout (delivery/pickup, UPI/cash choice), order + admin approval, product/stock management, notifications, order tracking.
- **Phase 2:** Online UPI payment (Razorpay), order history, reorder.
- **Phase 3 (optional):** AI reading of handwritten lists, offers/coupons, sales reports, loyalty, multi-language (Hindi/English).

---

## 6. Design mockup
- An interactive HTML prototype of ALL screens (customer + admin) was created and approved by the family.
- Location: `01-Design-Mockup/index.html` (open in any browser; toggle Customer App / Admin App at the top).
- Theme: saffron + green kirana colors. Text/colors/layout are all changeable.

---

## 7. Project folder structure
```
Desktop\Tirupati Traders App\
   ├── 01-Design-Mockup\      ← approved HTML designs (index.html)
   ├── 02-Flutter-App\        ← the Flutter app code (to be created)
   └── 03-Notes\              ← this file + plans
```
- **Flutter SDK** will be installed separately at `C:\dev\flutter` (short path, no spaces — required to avoid errors). The SDK is kept separate from the project; this is normal & correct.

---

## 8. Machine setup status (as of last check)
| Tool | Status |
|------|--------|
| Git | ✅ Installed (2.43.0) |
| Java JDK 21 | ✅ Installed |
| Android Studio | ✅ Installed at `C:\Program Files\Android\Android Studio` |
| **Flutter SDK** | ❌ NOT installed yet — this is the immediate next step |

---

## 9. Setup checklist (Phase 1 environment)
- [ ] **Install Flutter SDK** → clone stable to `C:\dev\flutter`
      `git clone https://github.com/flutter/flutter.git -b stable --depth 1` (run inside `C:\dev`)
- [ ] **Add Flutter to PATH** → add `C:\dev\flutter\bin` to the user PATH, restart terminal, verify with `flutter --version`
- [ ] **Run `flutter doctor`** → fix reported issues
- [ ] **Accept Android licenses** → `flutter doctor --android-licenses`
- [ ] **Install Flutter & Dart plugins** in Android Studio (Settings → Plugins)
- [ ] **Set up an Android emulator** (Android Studio → Device Manager) OR connect a physical Android phone with USB debugging on
- [ ] **Create the Flutter project** inside `02-Flutter-App`
      e.g. `flutter create tirupati_traders`
- [ ] **Run the starter app** on Android to confirm everything works (`flutter run`)

---

## 10. NEXT STEP (resume here)
**Install the Flutter SDK**, then add it to PATH and run `flutter doctor`.

The user is **new to Flutter and Android Studio**, so proceed **step by step**, one small step at a time, explaining each action in simple language and waiting for confirmation before moving on.

After environment setup works (starter app runs on Android), the next milestone is:
1. Draft the **Firestore data model** (users, products, orders, categories collections + fields).
2. Start building **Phase 1 screens** in Flutter, matching the approved mockup, beginning with the customer catalog and admin product management.

---

## 11. Useful reminders / constraints
- Test on **Android only** for now; iOS later (needs a Mac to build/publish).
- Publishing costs (later, not now): Google Play one-time ~$25; Apple Developer ~$99/year.
- Razorpay & online payment verification must include a small server-side check (Cloud Function) for security — never verify payment only inside the app.
- Prices change daily for loose items — admins must be able to edit price at approval time and anytime in product management.
