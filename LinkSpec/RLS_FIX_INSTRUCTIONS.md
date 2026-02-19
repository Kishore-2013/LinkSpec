# 🔧 FIXED: Infinite Recursion Error!

## ✅ The Problem is FIXED!

The error you saw:

```
Error loading profile: PostgrestException(message:
{"code":"42P17","details":null,"hint":null,"message":"Infinite recursion detected in policy for relation \"profiles\"},
code: 500, details: , hint: null)
```

This was caused by a bug in the RLS policies where they tried to SELECT from the same table they were protecting, creating infinite recursion.

---

## 🚀 How to Fix Your Database

### Option 1: Run the Fix Script (RECOMMENDED)

1. **Open Supabase Dashboard**:
   - Go to: https://supabase.com/dashboard/project/prghjnknjkrckbiqydgi

2. **Open SQL Editor**:
   - Click **SQL Editor** in left sidebar
   - Click **New Query**

3. **Run the Fix Script**:
   - Open `c:\ApplyWizz\LinkSpec\fix_rls_recursion.sql`
   - Copy ALL the contents
   - Paste into SQL Editor
   - Click **Run**

4. **Then Run the Full Schema**:
   - Open `c:\ApplyWizz\LinkSpec\supabase_schema.sql`
   - Copy ALL the contents
   - Paste into SQL Editor
   - Click **Run**

### Option 2: Fresh Start

If you haven't created any data yet:

1. **Drop all tables** (in SQL Editor):

   ```sql
   DROP TABLE IF EXISTS connections CASCADE;
   DROP TABLE IF EXISTS likes CASCADE;
   DROP TABLE IF EXISTS posts CASCADE;
   DROP TABLE IF EXISTS profiles CASCADE;
   DROP FUNCTION IF EXISTS get_user_domain(UUID);
   DROP FUNCTION IF EXISTS set_post_domain();
   ```

2. **Run the updated schema**:
   - Open `c:\ApplyWizz\LinkSpec\supabase_schema.sql`
   - Copy ALL the contents
   - Paste into SQL Editor
   - Click **Run**

---

## 🔍 What Was Fixed

### Before (BROKEN):

```sql
CREATE POLICY "Users can view profiles in same domain"
  ON profiles
  FOR SELECT
  USING (
    domain_id = (
      SELECT domain_id FROM profiles WHERE id = auth.uid()
      -- ❌ This SELECT also needs to check the policy!
      -- ❌ Creates infinite recursion!
    )
  );
```

### After (FIXED):

```sql
-- Helper function with SECURITY DEFINER (bypasses RLS)
CREATE OR REPLACE FUNCTION get_user_domain(user_id UUID)
RETURNS TEXT AS $$
BEGIN
  RETURN (SELECT domain_id FROM profiles WHERE id = user_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE POLICY "Users can view profiles in same domain"
  ON profiles
  FOR SELECT
  USING (
    auth.uid() = id  -- ✅ Can always see own profile
    OR
    domain_id = get_user_domain(auth.uid())  -- ✅ Uses function that bypasses RLS
  );
```

---

## 📊 What Changed

### Files Updated:

1. ✅ `supabase_schema.sql` - Fixed all RLS policies
2. ✅ `fix_rls_recursion.sql` - Migration script to fix existing databases

### Policies Fixed:

1. ✅ `profiles` SELECT policy - Now allows users to see own profile + same domain
2. ✅ `posts` SELECT policy - Uses SECURITY DEFINER function
3. ✅ `posts` INSERT policy - Uses SECURITY DEFINER function

### New Function:

- ✅ `get_user_domain(user_id UUID)` - Helper function with SECURITY DEFINER

---

## 🧪 After Running the Fix

### Test the App:

1. **Refresh your browser** (where the app is running)
2. **Try signing in again**
3. **Expected flow**:

   ```
   Sign In
     ↓
   Check if profile exists ✅ (No more error!)
     ├─ No profile → Domain Selection Screen
     └─ Has profile → Home Screen
   ```

4. **If you don't have a profile yet**:
   - You'll be taken to Domain Selection Screen
   - Choose your domain
   - Fill in your name
   - Click Continue
   - You'll be taken to Home Screen

---

## 🎯 Quick Copy-Paste

### Supabase Dashboard:

```
https://supabase.com/dashboard/project/prghjnknjkrckbiqydgi
```

### Files to Run (in order):

1. `c:\ApplyWizz\LinkSpec\fix_rls_recursion.sql` (if database already exists)
2. `c:\ApplyWizz\LinkSpec\supabase_schema.sql` (full schema)

---

## ✅ Summary

**The infinite recursion bug has been fixed!**

### What to do now:

1. ✅ Run `fix_rls_recursion.sql` in Supabase (if you already ran the old schema)
2. ✅ Run `supabase_schema.sql` in Supabase
3. ✅ Refresh your browser
4. ✅ Sign in again
5. ✅ App should work! 🎉

---

**The error is fixed in the code. Now you just need to update your database!** 🚀
