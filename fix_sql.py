import re
import sys

def process_file(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # Regex to find CREATE POLICY statements that contain the role check (already wrapped in EXECUTE or not)
    # Actually, we already wrapped them in EXECUTE.
    # Let's just find and replace "FROM users WHERE id = auth.uid()" with "FROM public.users WHERE id = auth.uid()" globally.
    new_content = content.replace("FROM users WHERE id = auth.uid()", "FROM public.users WHERE id = auth.uid()")
    
    # Also ensure the table creation uses public.users
    new_content = new_content.replace("CREATE TABLE IF NOT EXISTS users", "CREATE TABLE IF NOT EXISTS public.users")
    new_content = new_content.replace("ALTER TABLE users ADD COLUMN role", "ALTER TABLE public.users ADD COLUMN role")
    new_content = new_content.replace("table_name = 'users'", "table_name = 'users' AND table_schema = 'public'")

    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(new_content)
    print(f"Processed {filepath}")

process_file(r"c:\Users\CONSTANT_LE-GRAND\StudioProjects\admin_lebontaxi_web_panel\supabase_tables.sql")
process_file(r"c:\Users\CONSTANT_LE-GRAND\StudioProjects\users_app_final\supabase_subscription_tables.sql")
