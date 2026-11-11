-- File dialogs and small utilities float.
for _, title in ipairs({ "^(Open File)(.*)$", "^(Select a File)(.*)$", "^(Open Folder)(.*)$", "^(Save As)(.*)$", "^(File Upload)(.*)$" }) do
  hl.window_rule({ match = { title = title }, float = true })
  hl.window_rule({ match = { title = title }, center = true })
end
for _, class in ipairs({ "^(pavucontrol)$", "^(blueman-manager)$", "^(nm-connection-editor)$", "^(qalculate-gtk)$" }) do
  hl.window_rule({ match = { class = class }, float = true })
  hl.window_rule({ match = { class = class }, center = true })
end
-- Picture-in-picture
hl.window_rule({ match = { title = "^(Picture-in-Picture)$" }, float = true })
hl.window_rule({ match = { title = "^(Picture-in-Picture)$" }, pin = true })
