"use client";

import { Edit2, Image as ImageIcon, Info, Send, Trash2, Users, X } from "lucide-react";
import { use, useEffect, useRef, useState } from "react";
import { api, ApiError, endpoints, wsUrl } from "@/lib/api";
import { authHeaders, getToken } from "@/lib/auth";
import { formatTime } from "@/lib/format";
import { useCurrentUserId } from "@/lib/hooks/use-current-user-id";
import type { ChatMessage, GroupMember } from "@/lib/types";

export default function GroupChatPage({ params }: { params: Promise<{ groupId: string }> }) {
  const { groupId } = use(params);
  const currentUserId = useCurrentUserId();

  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [membersById, setMembersById] = useState<Record<string, GroupMember>>({});
  const [isLoadingHistory, setIsLoadingHistory] = useState(true);
  const [loadError, setLoadError] = useState<string | null>(null);
  const [connectionError, setConnectionError] = useState<string | null>(null);
  const [draft, setDraft] = useState("");
  const [editingId, setEditingId] = useState<string | null>(null);
  const [actionsFor, setActionsFor] = useState<ChatMessage | null>(null);

  const socketRef = useRef<WebSocket | null>(null);
  const listRef = useRef<HTMLDivElement>(null);

  const scrollToBottom = () => {
    requestAnimationFrame(() => {
      listRef.current?.scrollTo({ top: listRef.current.scrollHeight });
    });
  };

  const connect = () => {
    setConnectionError(null);
    const token = getToken();
    if (!token) {
      setConnectionError("You need to sign in again.");
      return;
    }
    const socket = new WebSocket(wsUrl(endpoints.chatWebSocket(groupId, token)));
    socketRef.current = socket;

    socket.onmessage = (event) => {
      try {
        const json = JSON.parse(event.data as string);
        const action = json.action as string | undefined;

        if (action === "message_deleted") {
          const id = json.message_id as string;
          setMessages((prev) => prev.map((m) => (m.id === id ? { ...m, message: "This message was deleted.", is_deleted: true } : m)));
          return;
        }
        if (action === "new_message" || action === "message_edited") {
          const data = json.message as ChatMessage;
          setMessages((prev) => (prev.some((m) => m.id === data.id) ? prev.map((m) => (m.id === data.id ? data : m)) : [...prev, data]));
          scrollToBottom();
          return;
        }
        // No action tag — tolerate a raw ChatMessage object too.
        if (json.id) {
          setMessages((prev) => [...prev, json as ChatMessage]);
          scrollToBottom();
        }
      } catch {
        // Ignore malformed frames rather than crash the chat.
      }
    };
    socket.onerror = () => setConnectionError("Connection lost. Tap to reconnect.");
    socket.onclose = () => setConnectionError("Disconnected. Tap to reconnect.");
  };

  useEffect(() => {
    let cancelled = false;
    (async () => {
      try {
        const [history, membersRes] = await Promise.all([
          api.getList(endpoints.chatHistory(groupId), authHeaders()),
          api.get(endpoints.groupMembers(groupId), authHeaders()),
        ]);
        if (cancelled) return;
        const sorted = (history as ChatMessage[]).slice().sort((a, b) => new Date(a.created_at).getTime() - new Date(b.created_at).getTime());
        setMessages(sorted);
        const members = (membersRes.data as GroupMember[]) ?? [];
        setMembersById(Object.fromEntries(members.map((m) => [m.user_id, m])));
        setIsLoadingHistory(false);
        scrollToBottom();
        connect();
      } catch (err) {
        if (cancelled) return;
        setLoadError(err instanceof ApiError ? err.message : "Couldn't load chat history.");
        setIsLoadingHistory(false);
      }
    })();
    return () => {
      cancelled = true;
      socketRef.current?.close();
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [groupId]);

  const send = () => {
    const text = draft.trim();
    if (!text) return;
    const socket = socketRef.current;
    if (!socket || socket.readyState !== WebSocket.OPEN) {
      setConnectionError("Not connected. Tap the banner to reconnect.");
      return;
    }
    if (editingId) {
      socket.send(JSON.stringify({ action: "edit", message_id: editingId, message: text }));
      setEditingId(null);
    } else {
      socket.send(JSON.stringify({ action: "send", message: text }));
    }
    setDraft("");
  };

  const startEdit = (message: ChatMessage) => {
    setEditingId(message.id);
    setDraft(message.message);
    setActionsFor(null);
  };

  const cancelEdit = () => {
    setEditingId(null);
    setDraft("");
  };

  const confirmDelete = (message: ChatMessage) => {
    setActionsFor(null);
    if (!confirm('Delete this message? This replaces it with "This message was deleted" for everyone in the group.')) return;
    socketRef.current?.send(JSON.stringify({ action: "delete", message_id: message.id }));
  };

  return (
    <div className="mx-auto flex h-[calc(100vh-6rem)] max-w-2xl flex-col px-6 py-6 sm:h-screen sm:py-8 lg:h-screen">
      <div className="flex items-center gap-2.5 border-b border-brand-dark/5 pb-4">
        <span className="flex h-9 w-9 items-center justify-center rounded-full bg-brand-pale">
          <Users size={16} className="text-brand-accent" />
        </span>
        <h1 className="font-display text-base font-bold text-brand-dark">Group Chat</h1>
      </div>

      {connectionError && (
        <button type="button" onClick={connect} className="mt-3 w-full rounded-xl bg-amber-50 py-2 text-center text-xs font-bold text-amber-600">
          {connectionError}
        </button>
      )}

      <div ref={listRef} className="mt-4 flex-1 space-y-3 overflow-y-auto pr-1">
        {isLoadingHistory ? (
          [0, 1, 2].map((i) => <div key={i} className="h-12 animate-pulse rounded-2xl bg-white" />)
        ) : loadError ? (
          <p className="py-10 text-center text-sm text-brand-dark/50">{loadError}</p>
        ) : messages.length === 0 ? (
          <p className="py-10 text-center text-sm text-brand-dark/40">No messages yet. Say hello 👋</p>
        ) : (
          messages.map((message) => {
            const isMe = !!message.sender_id && message.sender_id === currentUserId;
            const senderName = message.sender_id ? membersById[message.sender_id] : undefined;

            if (message.is_system) {
              return (
                <div key={message.id} className="mx-auto flex max-w-md items-start gap-2.5 rounded-2xl bg-brand-pale px-4 py-3">
                  <Info size={16} className="mt-0.5 shrink-0 text-brand-accent" />
                  <p className="text-sm text-brand-dark">{message.message}</p>
                </div>
              );
            }

            return (
              <div key={message.id} className={`flex ${isMe ? "justify-end" : "justify-start"}`}>
                <button
                  type="button"
                  onClick={() => isMe && !message.is_deleted && setActionsFor(message)}
                  className={`max-w-[75%] rounded-2xl px-4 py-2.5 text-left shadow-sm ${
                    isMe ? "rounded-br-md bg-brand" : "rounded-bl-md bg-white"
                  }`}
                >
                  {!isMe && <p className="mb-0.5 text-xs font-bold text-brand-accent">{senderName ? `${senderName.first_name} ${senderName.last_name}`.trim() : "Member"}</p>}
                  <p className={`text-sm ${message.is_deleted ? "italic text-brand-dark/40" : "text-brand-dark"}`}>{message.message}</p>
                  <div className="mt-1 flex items-center gap-1.5">
                    <span className="text-[10px] text-brand-dark/40">{formatTime(message.created_at)}</span>
                    {message.is_edited && !message.is_deleted && <span className="text-[10px] italic text-brand-dark/40">· edited</span>}
                  </div>
                </button>
              </div>
            );
          })
        )}
      </div>

      {editingId && (
        <div className="mt-3 flex items-center gap-2 rounded-xl bg-brand-pale px-3.5 py-2">
          <Edit2 size={13} className="text-brand-accent" />
          <span className="flex-1 text-xs font-bold text-brand-accent">Editing message</span>
          <button type="button" onClick={cancelEdit} className="text-brand-accent">
            <X size={15} />
          </button>
        </div>
      )}

      <div className="mt-3 flex items-center gap-2">
        <button type="button" onClick={() => alert("Image sharing coming soon")} className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full text-brand-dark/40 hover:bg-white">
          <ImageIcon size={18} />
        </button>
        <input
          value={draft}
          onChange={(e) => setDraft(e.target.value)}
          onKeyDown={(e) => e.key === "Enter" && send()}
          placeholder={editingId ? "Edit your message…" : "Message the group…"}
          className="flex-1 rounded-full bg-white px-4 py-2.5 text-sm text-brand-dark outline-none placeholder:text-brand-dark/30"
        />
        <button type="button" onClick={send} className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-brand text-brand-dark">
          <Send size={16} />
        </button>
      </div>

      {actionsFor && (
        <div className="fixed inset-0 z-50 flex items-end justify-center bg-brand-dark/40 backdrop-blur-sm sm:items-center" onClick={() => setActionsFor(null)}>
          <div className="w-full max-w-xs rounded-t-card bg-white p-2 shadow-2xl sm:rounded-card" onClick={(e) => e.stopPropagation()}>
            <button type="button" onClick={() => startEdit(actionsFor)} className="flex w-full items-center gap-3 rounded-xl px-4 py-3 text-sm font-semibold text-brand-dark hover:bg-soft-gray">
              <Edit2 size={16} />
              Edit
            </button>
            <button type="button" onClick={() => confirmDelete(actionsFor)} className="flex w-full items-center gap-3 rounded-xl px-4 py-3 text-sm font-semibold text-red-500 hover:bg-soft-gray">
              <Trash2 size={16} />
              Delete
            </button>
          </div>
        </div>
      )}
    </div>
  );
}
