-- Create Enum Types if not exist
DO $$ BEGIN
    CREATE TYPE event_type AS ENUM ('Wedding', 'Housewarming', 'Birthday', 'Other');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- Registries Table
CREATE TABLE IF NOT EXISTS registries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    event_type VARCHAR(255) NOT NULL,
    event_date DATE NOT NULL,
    event_location VARCHAR(255),
    is_public BOOLEAN DEFAULT true,
    address_pre_event JSONB,
    address_post_event JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Registry Items Table
CREATE TABLE IF NOT EXISTS registry_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    registry_id UUID REFERENCES registries(id) ON DELETE CASCADE,
    product_id INT REFERENCES products(id) ON DELETE CASCADE,
    quantity_requested INT DEFAULT 1,
    quantity_received INT DEFAULT 0,
    is_most_wanted BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(registry_id, product_id)
);

-- Enable RLS (Optional, since backend uses Service Key which bypasses RLS)
ALTER TABLE registries ENABLE ROW LEVEL SECURITY;
ALTER TABLE registry_items ENABLE ROW LEVEL SECURITY;

-- Optional basic policies (not strictly needed if operations go through our Node backend)
CREATE POLICY "Public profiles are viewable by everyone."
ON registries FOR SELECT
USING ( is_public = true );

CREATE POLICY "Users can manage their own registries."
ON registries FOR ALL
USING ( auth.uid() = user_id );

CREATE POLICY "Anyone can view public registry items."
ON registry_items FOR SELECT
USING ( 
  EXISTS (
    SELECT 1 FROM registries WHERE registries.id = registry_items.registry_id AND registries.is_public = true
  )
);
