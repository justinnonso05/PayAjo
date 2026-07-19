Here's everything, all still live on the backend:

Test accounts (all password: Password123)
Email	Username	KYC done?	PIN set?	Notes
smoketest_ajopay_qa@example.com	smoketestqa123	❌	❌	plain signup, no phone
smoketest_ajopay_qa2@example.com	smoketestqa456	❌	❌	signup with phone
smoketest_ajopay_qa3@example.com	smoketestqa789	✅	❌	good for testing "logged in, needs PIN" flow
smoketest_ajopay_qa4@example.com	smoketestqa999	❌	❌	admin of "QA Test Group" below
smoketest_ajopay_qa5@example.com	smoketestqa888	❌	❌	tried to join a group before KYC → got the "must complete KYC" error
smoketest_ajopay_qa6@example.com	smoketestqa777	✅	❌	already a member of "QA Test Group" (status: pending_approval)
Group to test Join with
Name: QA Test Group
Invite code: 80WBSV
Weekly, ₦5,000 contribution, payout day Monday, 70% quorum, shortfall policy "Hold", max 10 members
Status: gathering, 2 members so far (qa999 as admin, qa777 pending approval)


9. Smart Invite Link ⭐⭐⭐⭐

Instead of

AJO-04838

Users share

ajopay.app/invite/green-family

Cleaner.