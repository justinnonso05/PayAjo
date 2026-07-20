"use client";

import {
  BadgeCheck,
  Building2,
  Calendar,
  Camera,
  ChevronRight,
  FileText,
  Globe,
  HelpCircle,
  History,
  LifeBuoy,
  Lock,
  LockKeyhole,
  LogOut,
  Mail,
  MailPlus,
  Pencil,
  Phone,
  PlusCircle,
  Receipt,
  ShieldCheck,
  Users,
  Wallet,
} from "lucide-react";
import { useRouter } from "next/navigation";
import { useRef, useState } from "react";
import { EditProfileModal } from "@/components/app/edit-profile-modal";
import { api, ApiError, endpoints } from "@/lib/api";
import { authHeaders, clearToken } from "@/lib/auth";
import { formatShortDate } from "@/lib/format";
import { useInvites } from "@/lib/hooks/use-invites";
import { useProfile } from "@/lib/hooks/use-profile";

export default function ProfilePage() {
  const router = useRouter();
  const { profile, isLoading, refresh } = useProfile();
  const { invites } = useInvites();
  const fileInputRef = useRef<HTMLInputElement>(null);
  const [isUploadingAvatar, setIsUploadingAvatar] = useState(false);
  const [avatarError, setAvatarError] = useState<string | null>(null);
  const [showEditProfile, setShowEditProfile] = useState(false);

  const handleAvatarChange = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    e.target.value = "";
    if (!file) return;
    setIsUploadingAvatar(true);
    setAvatarError(null);
    try {
      await api.postFile(endpoints.avatar, file, authHeaders());
      await refresh();
    } catch (err) {
      setAvatarError(err instanceof ApiError ? err.message : "Couldn't upload your photo. Please try again.");
    } finally {
      setIsUploadingAvatar(false);
    }
  };

  return (
    <div className="mx-auto max-w-2xl px-6 py-8 sm:px-10 sm:py-10">
      <h1 className="font-display text-2xl font-bold text-brand-dark">Profile</h1>

      <div className="mt-6">
        {isLoading || !profile ? (
          <div className="h-40 animate-pulse rounded-card bg-white" />
        ) : (
          <div className="rounded-card bg-white p-6 text-center shadow-sm">
            <button
              type="button"
              onClick={() => fileInputRef.current?.click()}
              disabled={isUploadingAvatar}
              className="relative mx-auto flex h-16 w-16 items-center justify-center rounded-full bg-brand-pale font-display text-2xl font-bold text-brand-accent"
            >
              {profile.avatar_url ? (
                // eslint-disable-next-line @next/next/no-img-element -- remote Cloudinary URL, not a static/local asset
                <img src={profile.avatar_url} alt="" className="h-16 w-16 rounded-full object-cover" />
              ) : (
                (profile.first_name?.[0]?.toUpperCase() ?? "?")
              )}
              <span className="absolute -bottom-0.5 -right-0.5 flex h-6 w-6 items-center justify-center rounded-full bg-brand-accent text-white ring-2 ring-white">
                {isUploadingAvatar ? (
                  <span className="h-3 w-3 animate-spin rounded-full border-2 border-white border-t-transparent" />
                ) : (
                  <Camera size={12} />
                )}
              </span>
            </button>
            <input ref={fileInputRef} type="file" accept="image/*" className="hidden" onChange={handleAvatarChange} />
            {avatarError && <p className="mt-2 text-xs font-semibold text-red-500">{avatarError}</p>}

            <button type="button" onClick={() => setShowEditProfile(true)} className="mt-3 flex items-center justify-center gap-1.5">
              <p className="font-display text-lg font-bold text-brand-dark">{`${profile.first_name} ${profile.last_name}`.trim()}</p>
              {profile.kyc_status && <BadgeCheck size={17} className="text-brand-accent" />}
              <Pencil size={13} className="text-brand-dark/30" />
            </button>
            {profile.kyc_status && <p className="text-xs font-bold text-brand-accent">BVN Verified</p>}

            <div className="mx-auto mt-4 max-w-xs space-y-2 border-t border-brand-dark/5 pt-4 text-left">
              <InfoRow icon={Mail} text={profile.email || "—"} />
              <InfoRow icon={Phone} text={profile.phone || "Not set"} />
              <InfoRow icon={Calendar} text={profile.created_at ? `Member since ${formatShortDate(profile.created_at)}` : "Member since —"} />
            </div>
          </div>
        )}
      </div>

      {showEditProfile && profile && (
        <EditProfileModal
          profile={profile}
          onClose={() => setShowEditProfile(false)}
          onSaved={() => {
            setShowEditProfile(false);
            refresh();
          }}
        />
      )}

      <SettingsGroup title="Wallet">
        <SettingsRow icon={Wallet} label="Wallet Balance" onClick={() => router.push("/wallet")} />
        <SettingsRow icon={Receipt} label="Virtual Account" onClick={() => router.push("/wallet")} />
        <SettingsRow icon={History} label="Transaction History" onClick={() => router.push("/wallet")} />
        <SettingsRow icon={Building2} label="Payout Bank" trailing={profile?.payout_bank_account_number ? "Set" : "Not set"} onClick={() => router.push("/wallet/payout-bank")} />
      </SettingsGroup>

      <SettingsGroup title="Security">
        {profile && !profile.has_pin ? (
          <SettingsRow icon={Lock} label="Create PIN" onClick={() => router.push("/pin-setup")} />
        ) : (
          <SettingsRow icon={LockKeyhole} label="Reset PIN" onClick={() => router.push("/reset-pin")} />
        )}
      </SettingsGroup>

      <SettingsGroup title="Savings">
        <SettingsRow icon={Users} label="My Groups" onClick={() => router.push("/home")} />
        <SettingsRow icon={MailPlus} label="My Invites" trailing={invites.length > 0 ? `${invites.length} new` : undefined} onClick={() => router.push("/invites")} />
        <SettingsRow icon={PlusCircle} label="Join or Create a Group" onClick={() => router.push("/join-or-create")} />
      </SettingsGroup>

      <SettingsGroup title="Account">
        <SettingsRow icon={ShieldCheck} label="KYC Status" trailing={profile?.kyc_status ? "Verified" : "Not verified"} onClick={() => alert("Coming soon")} />
        <SettingsRow icon={Globe} label="Language" onClick={() => alert("Coming soon")} />
        <SettingsRow icon={HelpCircle} label="Help Center" onClick={() => alert("Coming soon")} />
        <SettingsRow icon={LifeBuoy} label="Support" onClick={() => alert("Coming soon")} />
        <SettingsRow icon={FileText} label="Terms" onClick={() => alert("Coming soon")} />
      </SettingsGroup>

      <SettingsGroup title="">
        <LogoutRow />
      </SettingsGroup>
    </div>
  );
}

function InfoRow({ icon: Icon, text }: { icon: typeof Mail; text: string }) {
  return (
    <div className="flex items-center gap-2.5">
      <Icon size={14} className="text-brand-dark/30" />
      <span className="text-sm text-brand-dark/60">{text}</span>
    </div>
  );
}

function SettingsGroup({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <div className="mt-6">
      {title && <p className="mb-2.5 px-1 text-xs font-bold text-brand-dark/40">{title}</p>}
      <div className="divide-y divide-brand-dark/5 rounded-card bg-white shadow-sm">{children}</div>
    </div>
  );
}

function SettingsRow({ icon: Icon, label, trailing, onClick }: { icon: typeof Mail; label: string; trailing?: string; onClick: () => void }) {
  return (
    <button type="button" onClick={onClick} className="flex w-full items-center gap-3.5 px-5 py-3.5 text-left transition-colors hover:bg-soft-gray">
      <Icon size={18} className="text-brand-dark/50" />
      <span className="flex-1 text-sm font-semibold text-brand-dark">{label}</span>
      {trailing && <span className="text-xs text-brand-dark/40">{trailing}</span>}
      <ChevronRight size={16} className="text-brand-dark/30" />
    </button>
  );
}

function LogoutRow() {
  const router = useRouter();
  const handleLogout = () => {
    if (!confirm("Log out? You can log back in anytime with your email and password.")) return;
    clearToken();
    router.push("/login");
  };

  return (
    <button type="button" onClick={handleLogout} className="flex w-full items-center gap-3.5 px-5 py-3.5 text-left text-red-500 transition-colors hover:bg-red-50">
      <LogOut size={18} />
      <span className="flex-1 text-sm font-bold">Logout</span>
    </button>
  );
}
