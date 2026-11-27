"use client";
import { useState } from "react";
export default function PasswordField({ name }: { name: string }) {
  const [visible, setVisible] = useState(false);
  return <div className="flex mt-1"><input name={name} type={visible ? "text" : "password"} required className="w-full border rounded-l p-3" /><button type="button" onClick={() => setVisible(!visible)} className="border rounded-r px-3" aria-label={visible ? "Hide password" : "Show password"}>{visible ? "Hide" : "Show"}</button></div>;
}
