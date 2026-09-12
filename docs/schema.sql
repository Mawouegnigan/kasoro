-- Kasoro — Schéma de base de données (messagerie)
-- PostgreSQL 14+ (utilise gen_random_uuid(), extension pgcrypto ou pg_uuidv7)
--
-- Principe central : traduction à la demande, mise en cache par langue.
-- Un message n'est jamais traduit vers plus de langues que celles
-- réellement présentes dans les membres de sa conversation.

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ============================================================
-- USERS
-- ============================================================
CREATE TABLE users (
    id                        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    phone_number              VARCHAR(20) UNIQUE NOT NULL,
    display_name              VARCHAR(100) NOT NULL,
    avatar_url                TEXT,
    voice_tag_url             TEXT,        -- audio où l'utilisateur dit lui-même son nom (source prioritaire)
    voice_tag_generated_url   TEXT,        -- fallback TTS si pas d'audio enregistré
    primary_language          VARCHAR(10) NOT NULL,  -- ex: 'yo', 'fon', 'fr'
    created_at                TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================================
-- CONTACTS (relation entre deux utilisateurs, pas un simple annuaire)
-- ============================================================
CREATE TABLE contacts (
    id                     UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id               UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    contact_user_id        UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    custom_voice_tag_url   TEXT,  -- label vocal personnalisé (prioritaire sur voice_tag_url du contact)
    created_at             TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (owner_id, contact_user_id),
    CHECK (owner_id != contact_user_id)
);

CREATE INDEX idx_contacts_owner ON contacts(owner_id);

-- ============================================================
-- CONVERSATIONS
-- ============================================================
CREATE TABLE conversations (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    type         VARCHAR(10) NOT NULL CHECK (type IN ('direct', 'group')),
    name         VARCHAR(100),   -- vide pour les conversations directes
    avatar_url   TEXT,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================================
-- CONVERSATION_MEMBERS
-- Table pivot : détermine quelles langues sont réellement présentes
-- dans une conversation, pour ne traduire que vers celles-ci.
-- ============================================================
CREATE TABLE conversation_members (
    id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id   UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
    user_id           UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role              VARCHAR(10) NOT NULL DEFAULT 'member' CHECK (role IN ('member', 'admin')),
    joined_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (conversation_id, user_id)
);

CREATE INDEX idx_conv_members_conversation ON conversation_members(conversation_id);
CREATE INDEX idx_conv_members_user ON conversation_members(user_id);

-- ============================================================
-- MESSAGES
-- ============================================================
CREATE TABLE messages (
    id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id       UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
    sender_id             UUID NOT NULL REFERENCES users(id),
    original_type         VARCHAR(10) NOT NULL CHECK (original_type IN ('text', 'audio')),
    original_text         TEXT,        -- texte saisi, ou transcription si message vocal
    original_audio_url    TEXT,        -- fichier audio d'origine si original_type = 'audio'
    original_language     VARCHAR(10) NOT NULL,
    created_at            TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Index composite : la requête la plus fréquente est "messages d'une
-- conversation, du plus récent au plus ancien" (pagination du chat).
CREATE INDEX idx_messages_conversation_created ON messages(conversation_id, created_at DESC);

-- ============================================================
-- MESSAGE_TRANSLATIONS
-- Le cœur du système de cache : (message_id, language) est unique,
-- donc une traduction n'est jamais générée deux fois pour la même paire.
-- ============================================================
CREATE TABLE message_translations (
    id                     UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    message_id             UUID NOT NULL REFERENCES messages(id) ON DELETE CASCADE,
    language               VARCHAR(10) NOT NULL,
    translated_text        TEXT,
    translated_audio_url   TEXT,
    status                 VARCHAR(10) NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'ready', 'failed')),
    generated_at           TIMESTAMPTZ,
    UNIQUE (message_id, language)
);

CREATE INDEX idx_msg_translations_message ON message_translations(message_id);

-- ============================================================
-- Requête type : langues réellement présentes dans une conversation
-- (à utiliser pour décider quelles traductions déclencher en priorité
-- dès l'envoi d'un message, plutôt que d'attendre que chacun l'ouvre)
-- ============================================================
-- SELECT DISTINCT u.primary_language
-- FROM conversation_members cm
-- JOIN users u ON u.id = cm.user_id
-- WHERE cm.conversation_id = $1;