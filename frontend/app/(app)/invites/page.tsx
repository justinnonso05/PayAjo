"use client";

import { Mail, Users } from "lucide-react";
import { useState } from "react";
import { EmptyState } from "@/components/app/empty-state";
import { formatShortDate } from "@/lib/format";
import { useGroups } from "@/lib/hooks/use-groups";
import { useInvites } from "@/lib/hooks/use-invites";

export default function InvitesPage() {
  const { invites, isLoading, error, respond } = useInvites();
  const { refresh: refreshGroups } = useGroups();
  const [respondingId, setRespondingId] = useState<string | null>(null);

  const handleRespond = async (inviteId: string, accept: boolean) => {
    setRespondingId(inviteId);
    try {
      await respond(inviteId, accept);
      if (accept) await refreshGroups();
    } finally {
      setRespondingId(null);
    }
  };

  return (
    <div className="mx-auto max-w-2xl px-6 py-8 sm:px-10 sm:py-10">
      <h1 className="font-display text-2xl font-bold text-brand-dark">My Invites</h1>

      <div className="mt-6">
        {isLoading ? (
          <div className="space-y-4">
            {[0, 1].map((i) => (
              <div key={i} className="h-24 animate-pulse rounded-card bg-white" />
            ))}
          </div>
        ) : error ? (
          <div className="rounded-card bg-white shadow-sm">
            <EmptyState icon={Mail} title="Couldn't load invites" subtitle={error} />
          </div>
        ) : invites.length === 0 ? (
          <div className="rounded-card bg-white shadow-sm">
            <EmptyState icon={Mail} title="No pending invites." subtitle="When a group admin invites you directly, it'll show up here." />
          </div>
        ) : (
          <div className="space-y-4">
            {invites.map(({ invite, groupName }) => {
              const isBusy = respondingId === invite.id;
              return (
                <div key={invite.id} className="rounded-card bg-white p-5 shadow-sm">
                  <div className="flex items-center gap-3">
                    <span className="flex h-11 w-11 items-center justify-center rounded-full bg-brand-pale">
                      <Users size={18} className="text-brand-accent" />
                    </span>
                    <div className="min-w-0 flex-1">
                      <p className="truncate font-display text-sm font-bold text-brand-dark">{groupName}</p>
                      <p className="text-xs text-brand-dark/40">Invited {formatShortDate(invite.created_at)}</p>
                    </div>
                  </div>
                  <div className="mt-4 flex gap-3">
                    <button
                      type="button"
                      disabled={isBusy}
                      onClick={() => handleRespond(invite.id, false)}
                      className="flex-1 rounded-full border border-brand-dark/15 py-2.5 text-xs font-bold text-brand-dark/60 disabled:opacity-50"
                    >
                      Decline
                    </button>
                    <button
                      type="button"
                      disabled={isBusy}
                      onClick={() => handleRespond(invite.id, true)}
                      className="flex-1 rounded-full bg-brand py-2.5 text-xs font-bold text-brand-dark disabled:opacity-50"
                    >
                      {isBusy ? "…" : "Accept"}
                    </button>
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </div>
    </div>
  );
}
