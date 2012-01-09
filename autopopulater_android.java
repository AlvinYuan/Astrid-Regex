    public static void parseQuickAddMarkup(Task task, ArrayList<String> tags) {
        String title = task.getValue(Task.TITLE);

        Pattern tagPattern = Pattern.compile("(\\s|^)#([^\\s]+)");
        Pattern contextPattern = Pattern.compile("(\\s|^)(@[^\\s]+)");
        Pattern importancePattern = Pattern.compile("(\\s|^)!(\\d)(\\s|$)");
        while(true) {
            Matcher m = tagPattern.matcher(title);
            if(m.find()) {
                tags.add(m.group(2));
            } else {
                m = contextPattern.matcher(title);
                if(m.find()) {
                    tags.add(m.group(2));
                } else {
                    m = importancePattern.matcher(title);
                    if(m.find()) {
                        int value = Integer.parseInt(m.group(2));
                        // not in producteev world: !1 to !4 => importance 3 to 0
                        int importance = Math.max(Task.IMPORTANCE_MOST, Task.IMPORTANCE_LEAST + 1 - value);
                        // in the producteev world, !1 to !4 => importance 4 to 1
                        if(ProducteevUtilities.INSTANCE.isLoggedIn() || OpencrxCoreUtils.INSTANCE.isLoggedIn())
                            importance++;

                        task.setValue(Task.IMPORTANCE, importance);
                    } else
                        break;
                }
            }

            title = title.substring(0, m.start()) + title.substring(m.end());
        }
        task.setValue(Task.TITLE, title.trim());
    }